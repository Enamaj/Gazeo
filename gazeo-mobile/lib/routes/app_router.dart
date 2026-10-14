import 'package:go_router/go_router.dart';
import '../screens/carte_screen.dart';
import '../screens/fiche_depot_screen.dart';
import '../screens/suivi_livraison_screen.dart';
import '../screens/livreur/tableau_bord_livreur_screen.dart';
import '../screens/livreur/liste_missions_screen.dart';
import '../screens/livreur/mission_active_screen.dart';
import '../screens/livreur/historique_livraisons_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CarteScreen(),
    ),
    GoRoute(
      path: '/depot/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final depotId = int.tryParse(idStr) ?? 1;
        return FicheDepotScreen(depotId: depotId);
      },
    ),
    GoRoute(
      path: '/suivi/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '1';
        final cmdId = int.tryParse(idStr) ?? 1;
        final otp = state.uri.queryParameters['otp'];
        return SuiviLivraisonScreen(commandeId: cmdId, codeConfirmation: otp);
      },
    ),
    GoRoute(
      path: '/livreur/tableau-de-bord',
      builder: (context, state) => const TableauBordLivreurScreen(),
    ),
    GoRoute(
      path: '/livreur/missions',
      builder: (context, state) => const ListeMissionsScreen(),
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

