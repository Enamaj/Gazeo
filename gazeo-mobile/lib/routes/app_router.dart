import 'package:go_router/go_router.dart';

import '../screens/accueil_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/commande_livraison_screen.dart';
import '../screens/chat_livreur_screen.dart';
import '../screens/profil_pages.dart';
import '../screens/onboarding_screen.dart';
import '../screens/choix_compte_screen.dart';
import '../screens/carte_screen.dart';
import '../screens/liste_depots_screen.dart';
import '../screens/fiche_depot_screen.dart';
import '../screens/commande_selection_screen.dart';
import '../screens/suivi_livraison_screen.dart';
import '../screens/mon_compte_screen.dart';
import '../screens/paiement_screen.dart';
import '../screens/connexion_screen.dart';
import '../screens/attente_acceptation_screen.dart';
import '../screens/gerant/tableau_bord_gerant_screen.dart';
import '../screens/livreur/tableau_bord_livreur_screen.dart';
import '../screens/livreur/liste_missions_screen.dart';
import '../screens/livreur/mission_active_screen.dart';
import '../screens/livreur/historique_livraisons_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // Écran 1 : Accueil
    // Écran de chargement (barre de progression) au démarrage
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/accueil',
      builder: (context, state) => const AccueilScreen(),
    ),

    // Écran 2 : Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Écran 3 : Choix du compte
    GoRoute(
      path: '/choix-compte',
      builder: (context, state) => const ChoixCompteScreen(),
    ),

    // Écran 4 : Carte client (Écran principal)
    GoRoute(
      path: '/',
      builder: (context, state) => const CarteScreen(),
    ),

    // Écran 5 : Liste des dépôts
    GoRoute(
      path: '/depots',
      builder: (context, state) => const ListeDepotsScreen(),
    ),

    // Écran 6 : Détail d'un dépôt
    GoRoute(
      path: '/depot/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final depotId = int.tryParse(idStr) ?? 1;
        return FicheDepotScreen(depotId: depotId);
      },
    ),

    // Écran 7 : Commande - sélection du produit
    GoRoute(
      path: '/commande/selection/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final depotId = int.tryParse(idStr) ?? 1;
        return CommandeSelectionScreen(
          depotId: depotId,
          tailleInitiale: state.uri.queryParameters['taille'],
        );
      },
    ),

    // Étape 2 du tunnel de commande : Livraison
    GoRoute(
      path: '/commande/livraison',
      builder: (context, state) {
        final q = state.uri.queryParameters;
        return CommandeLivraisonScreen(
          depotId: int.tryParse(q['depotId'] ?? '') ?? 1,
          taille: q['taille'] ?? '12.5 kg',
          quantite: int.tryParse(q['quantite'] ?? '') ?? 1,
          montant: int.tryParse(q['montant'] ?? '') ?? 13000,
        );
      },
    ),

    // Messagerie intégrée client ↔ livreur
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) => ChatLivreurScreen(
        commandeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 1,
      ),
    ),

    // Écran 8 : Suivi de commande
    GoRoute(
      path: '/suivi/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final cmdId = int.tryParse(idStr) ?? 1;
        final otp = state.extra is String
            ? state.extra as String
            : state.uri.queryParameters['otp'];
        return SuiviLivraisonScreen(commandeId: cmdId, codeConfirmation: otp);
      },
    ),

    // Écran 9 : Mon compte
    GoRoute(
      path: '/compte',
      builder: (context, state) => const MonCompteScreen(),
    ),
    GoRoute(path: '/compte/adresses', builder: (context, state) => const MesAdressesScreen()),
    GoRoute(path: '/compte/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/compte/aide', builder: (context, state) => const AideSupportScreen()),
    GoRoute(path: '/compte/parametres', builder: (context, state) => const ParametresScreen()),

    // Écran 10 : Gestion du dépôt (gérant)
    GoRoute(
      path: '/gerant/tableau-de-bord',
      builder: (context, state) => const TableauBordGerantScreen(),
    ),

    // Écran 11 : Livreur - missions
    GoRoute(
      path: '/livreur/missions',
      builder: (context, state) => const ListeMissionsScreen(),
    ),

    // Écran 12 : Paiement
    GoRoute(
      path: '/paiement',
      builder: (context, state) {
        final dIdStr = state.uri.queryParameters['depotId'];
        final depotId = int.tryParse(dIdStr ?? '1') ?? 1;
        final montantStr = state.uri.queryParameters['montant'];
        final montant = int.tryParse(montantStr ?? '8500') ?? 8500;
        final articlesStr = state.uri.queryParameters['articles'];
        final articles = int.tryParse(articlesStr ?? '1') ?? 1;
        final frais = int.tryParse(state.uri.queryParameters['frais'] ?? '1000') ?? 1000;
        return PaiementScreen(
          depotId: depotId,
          montant: montant,
          articles: articles,
          fraisLivraison: frais,
        );
      },
    ),

    // Routes additionnelles pour compatibilité & flux avancés
    GoRoute(
      path: '/connexion',
      builder: (context, state) => const ConnexionScreen(),
    ),
    GoRoute(
      path: '/commande/attente/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '101';
        final cmdId = int.tryParse(idStr) ?? 101;
        return AttenteAcceptationScreen(
          commandeId: cmdId,
          paymentUrl: state.uri.queryParameters['paymentUrl'],
        );
      },
    ),
    GoRoute(
      path: '/livreur/tableau-de-bord',
      builder: (context, state) => const TableauBordLivreurScreen(),
    ),
    GoRoute(
      path: '/livreur/mission-active/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final cmdId = int.tryParse(idStr) ?? 1;
        return MissionActiveScreen(commandeId: cmdId);
      },
    ),
    GoRoute(
      path: '/livreur/historique',
      builder: (context, state) => const HistoriqueLivraisonsScreen(),
    ),
  ],
);
