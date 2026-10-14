import 'package:go_router/go_router.dart';
import '../screens/carte_screen.dart';
import '../screens/fiche_depot_screen.dart';

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
  ],
);

