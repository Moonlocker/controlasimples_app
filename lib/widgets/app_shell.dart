import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_wizard_screen.dart';
import '../repositories/auth_repository.dart';
import '../repositories/workspace_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Conta bloqueada pelo superadmin: encerra a sessão, como no fluxo web.
    ref.listen(workspaceProvider, (previous, next) {
      final profile = next.value?.profile;
      if (profile != null && !profile.active) {
        ref.read(authRepositoryProvider).signOut();
      }
    });

    // Primeiro acesso: assistente guiado de configuração (conta, marca e plano).
    final workspace = ref.watch(workspaceProvider).value;
    if (workspace != null &&
        !workspace.isSuperadmin &&
        workspace.profile?.setupCompleted == false) {
      return const OnboardingWizardScreen();
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Visão geral',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Cobranças',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}
