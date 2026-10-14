import os
from pathlib import Path
import qrcode
from django.core.management.base import BaseCommand
from depots.models import Depot


class Command(BaseCommand):
    help = "Génère les QR codes d'onboarding gérants pour tous les dépôts de Yaoundé (Prompt 9.3)"

    def add_arguments(self, parser):
        parser.add_argument(
            '--output-dir',
            type=str,
            default='media/qr_codes',
            help="Répertoire de destination pour les fichiers PNG de QR codes"
        )
        parser.add_argument(
            '--base-url',
            type=str,
            default='https://gazeo.cm/onboarding/gerant',
            help="URL de base de redirection d'onboarding gérant"
        )

    def handle(self, *args, **options):
        output_dir = Path(options['output_dir'])
        output_dir.mkdir(parents=True, exist_ok=True)
        base_url = options['base_url']

        depots = Depot.objects.filter(est_actif=True).order_by('quartier', 'nom')
        total = depots.count()
        self.stdout.write(f"Génération des QR codes pour {total} dépôts dans : {output_dir}")

        fiches_html = []

        for depot in depots:
            qr_content = f"{base_url}?depot_id={depot.id}&tel={depot.telephone}"
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_M,
                box_size=10,
                border=4,
            )
            qr.add_data(qr_content)
            qr.make(fit=True)

            img = qr.make_image(fill_color="black", back_color="white")
            filename = f"depot_{depot.id}_{depot.quartier.lower()}.png"
            filepath = output_dir / filename
            img.save(str(filepath))

            fiches_html.append(f"""
            <div class="card">
                <h2>{depot.nom}</h2>
                <p><strong>Quartier :</strong> {depot.quartier}</p>
                <p><strong>Téléphone :</strong> {depot.telephone}</p>
                <p><strong>Marque :</strong> {depot.get_marque_display()}</p>
                <img src="{filename}" alt="QR Code {depot.nom}" />
                <p class="instruction">Scannez ce QR Code pour activer votre espace gérant GAZEO</p>
                <p class="url">{qr_content}</p>
            </div>
            """)

        # Générer un catalogue HTML prêt à imprimer pour l'équipe terrain
        catalogue_path = output_dir / "catalogue_qr_a_imprimer.html"
        html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Catalogue QR Codes GAZEO — Onboarding Gérants Yaoundé</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; padding: 20px; }}
        h1 {{ text-align: center; color: #1e3a8a; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; }}
        .card {{ background: white; border: 2px solid #e2e8f0; border-radius: 12px; padding: 20px; text-align: center; page-break-inside: avoid; }}
        .card h2 {{ font-size: 16px; margin: 0 0 10px 0; color: #0f172a; }}
        .card p {{ margin: 4px 0; font-size: 13px; color: #475569; }}
        .card img {{ width: 180px; height: 180px; margin: 12px 0; }}
        .instruction {{ font-size: 12px; font-weight: bold; color: #059669; }}
        .url {{ font-size: 10px; color: #94a3b8; word-break: break-all; }}
        @media print {{ body {{ background: white; }} .card {{ border: 1px solid #cbd5e1; box-shadow: none; }} }}
    </style>
</head>
<body>
    <h1>🔥 GAZEO — Fiches QR Code d'Onboarding Terrain (Yaoundé)</h1>
    <p style="text-align:center; color:#64748b;">50 Dépôts Pilotes : Bastos, Melen, Biyem-Assi, Omnisports, Nlongkak</p>
    <div class="grid">
        {"".join(fiches_html)}
    </div>
</body>
</html>
"""
        catalogue_path.write_text(html_content, encoding='utf-8')

        self.stdout.write(
            self.style.SUCCESS(
                f"✅ {total} QR codes générés avec succès !\n"
                f"Catalogue HTML prêt pour impression terrain : {catalogue_path}"
            )
        )

