import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/admin/admin_asaas_screen.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/admin/admin_plans_screen.dart';
import '../../features/admin/admin_user_detail_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_whatsapp_screen.dart';
import '../../features/charges/charges_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/portal/portal_screen.dart';
import '../../features/quotes/quote_editor_screen.dart';
import '../../features/quotes/quotes_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/services/service_detail_screen.dart';
import '../../features/services/services_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../models/quote.dart';
import '../../services/supabase_service.dart';
import '../../widgets/admin_gate.dart';
import '../../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final refresh = AuthRefreshNotifier(supabase.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = supabase.auth.currentSession != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/services',
                builder: (context, state) => const ServicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/charges',
                builder: (context, state) => const ChargesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: '/notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  GoRoute(
                    path: '/quotes',
                    builder: (context, state) => const QuotesScreen(),
                    routes: [
                      GoRoute(
                        path: '/new',
                        builder: (context, state) => QuoteEditorScreen(
                          duplicateFrom: state.extra is Quote
                              ? state.extra as Quote
                              : null,
                        ),
                      ),
                      GoRoute(
                        path: '/:id',
                        builder: (context, state) => QuoteEditorScreen(
                          quoteId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: '/reports',
                    builder: (context, state) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: '/portal',
                    builder: (context, state) => const PortalScreen(),
                  ),
                  ShellRoute(
                    builder: (context, state, child) => AdminGate(child: child),
                    routes: [
                      GoRoute(
                        path: '/admin',
                        builder: (context, state) => const AdminHomeScreen(),
                      ),
                      GoRoute(
                        path: '/admin/users',
                        builder: (context, state) => const AdminUsersScreen(),
                      ),
                      GoRoute(
                        path: '/admin/users/:id',
                        builder: (context, state) => AdminUserDetailScreen(
                          userId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: '/admin/plans',
                        builder: (context, state) => const AdminPlansScreen(),
                      ),
                      GoRoute(
                        path: '/admin/whatsapp',
                        builder: (context, state) =>
                            const AdminWhatsappScreen(),
                      ),
                      GoRoute(
                        path: '/admin/asaas',
                        builder: (context, state) => const AdminAsaasScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/services/:id',
        builder: (context, state) =>
            ServiceDetailScreen(serviceId: state.pathParameters['id']!),
      ),
    ],
  );
});

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
