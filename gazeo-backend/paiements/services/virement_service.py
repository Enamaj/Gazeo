import logging
import uuid
from django.conf import settings
from django.db import transaction
from paiements.models import VirementCommande, TypeVirement, StatutVirement
from paiements.services.notchpay_service import NotchpayService

logger = logging.getLogger(__name__)


class VirementService:
    """
    Gère la répartition des fonds et l'exécution des virements lors de la livraison :
    1. montant_gerant -> numéro MoMo du gérant (prix_bouteille + 80% frais_livraison)
    2. commission_gazeo -> compte GAZEO (20% frais_livraison)
    """

    @classmethod
    def executer_repartition_livraison(cls, commande) -> dict:
        """
        Déclenche et enregistre les deux virements pour une commande livrée.
        Idempotent : ne réexécute pas si les virements existent déjà pour cette commande.
        """
        virements_existants = VirementCommande.objects.filter(commande=commande)
        if virements_existants.exists():
            logger.info(f"[VirementService] Virements déjà existants pour la commande #{commande.id}.")
            return {
                "statut": "deja_traite",
                "virements": list(virements_existants)
            }

        notchpay = NotchpayService()
        numero_gerant = ""
        if commande.depot and commande.depot.gerant:
            numero_gerant = commande.depot.gerant.telephone or ""

        compte_gazeo = getattr(settings, 'GAZEO_COMPTE_MARCHAND', 'GAZEO_PLATFORM_ACCOUNT')

        montant_gerant = int(commande.montant_gerant)
        commission_gazeo = int(commande.commission_gazeo)

        logger.info(
            f"[VirementService] Déclenchement virements Commande #{commande.id} : "
            f"Gérant ({numero_gerant}) = {montant_gerant} FCFA | "
            f"GAZEO ({compte_gazeo}) = {commission_gazeo} FCFA"
        )

        ref_gerant = f"VIR-GER-{commande.id}-{uuid.uuid4().hex[:6].upper()}"
        ref_gazeo = f"VIR-GAZ-{commande.id}-{uuid.uuid4().hex[:6].upper()}"

        # 1. Transfert Notchpay gérant
        res_gerant = notchpay.effectuer_transfert(
            beneficiaire=numero_gerant,
            montant=montant_gerant,
            description=f"Règlement GAZEO Commande #{commande.id} pour gérant",
            reference=ref_gerant
        )

        # 2. Transfert / Versement Notchpay commission GAZEO
        res_gazeo = notchpay.effectuer_transfert(
            beneficiaire=compte_gazeo,
            montant=commission_gazeo,
            description=f"Commission GAZEO Commande #{commande.id}",
            reference=ref_gazeo
        )

        # Enregistrement en base de données
        with transaction.atomic():
            virement_gerant = VirementCommande.objects.create(
                commande=commande,
                type_virement=TypeVirement.GERANT_MOMO,
                beneficiaire=numero_gerant,
                montant=montant_gerant,
                statut=StatutVirement.VIRE if res_gerant.get('status') == 'success' else StatutVirement.EN_ATTENTE,
                reference_transfert=res_gerant.get('reference', ref_gerant),
            )

            virement_gazeo = VirementCommande.objects.create(
                commande=commande,
                type_virement=TypeVirement.GAZEO_COMMISSION,
                beneficiaire=compte_gazeo,
                montant=commission_gazeo,
                statut=StatutVirement.VIRE if res_gazeo.get('status') == 'success' else StatutVirement.EN_ATTENTE,
                reference_transfert=res_gazeo.get('reference', ref_gazeo),
            )

        return {
            "statut": "succes",
            "virement_gerant": {
                "id": virement_gerant.id,
                "beneficiaire": virement_gerant.beneficiaire,
                "montant": virement_gerant.montant,
                "reference": virement_gerant.reference_transfert,
            },
            "virement_gazeo": {
                "id": virement_gazeo.id,
                "beneficiaire": virement_gazeo.beneficiaire,
                "montant": virement_gazeo.montant,
                "reference": virement_gazeo.reference_transfert,
            }
        }
