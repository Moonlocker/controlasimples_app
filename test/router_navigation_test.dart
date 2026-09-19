import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Garante que os submenus do ramo "Mais" mantêm a barra de navegação inferior
/// com o ramo "Mais" selecionado, enquanto telas de detalhe permanecem em tela
/// cheia (sem barra).
void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
                NavigationDestination(
                  icon: Icon(Icons.work),
                  label: 'Serviços',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'Mais',
                ),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (_, _) => const Text('DASH'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/services',
                  builder: (_, _) => const Text('SERVICES'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (_, _) => const Text('MORE'),
                  routes: [
                    GoRoute(
                      path: '/settings',
                      builder: (_, _) => const Text('SETTINGS'),
                    ),
                    ShellRoute(
                      builder: (_, _, child) => child,
                      routes: [
                        GoRoute(
                          path: '/admin',
                          builder: (_, _) => const Text('ADMIN'),
                        ),
                        GoRoute(
                          path: '/admin/users',
                          builder: (_, _) => const Text('ADMIN USERS'),
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
          path: '/services/:id',
          builder: (_, state) => Text('SERVICE ${state.pathParameters['id']}'),
        ),
      ],
    );
  });

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('submenu do Mais mantém a barra e seleciona o Mais', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('DASH'), findsOneWidget);

    router.go('/more/settings');
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selectedIndex(tester), 2);
  });

  testWidgets('rota aninhada com ShellRoute mantém a barra', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/more/admin/users');
    await tester.pumpAndSettle();
    expect(find.text('ADMIN USERS'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selectedIndex(tester), 2);
  });

  testWidgets('push dentro do ramo Mais mantém a barra', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/more');
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), 2);

    router.push('/more/settings');
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selectedIndex(tester), 2);
  });

  testWidgets('detalhe de serviço permanece em tela cheia', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/services/abc');
    await tester.pumpAndSettle();
    expect(find.text('SERVICE abc'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
