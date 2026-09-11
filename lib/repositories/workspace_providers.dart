import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';
import '../models/workspace.dart';
import 'workspace_repository.dart';

final workspaceProvider = FutureProvider<Workspace>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    throw StateError('Usuário não autenticado.');
  }
  return ref.watch(workspaceRepositoryProvider).fetchWorkspace(userId);
});
