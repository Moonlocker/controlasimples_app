import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/workspace_providers.dart';
import 'async_error_view.dart';

/// Restringe o acesso às rotas administrativas a superadministradores.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(workspaceProvider);
    return workspaceAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Administração')),
        body: AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(workspaceProvider),
        ),
      ),
      data: (workspace) {
        if (!workspace.isSuperadmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso restrito')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta área é exclusiva do administrador.'),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
