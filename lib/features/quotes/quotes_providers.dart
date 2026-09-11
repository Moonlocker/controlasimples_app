import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote.dart';
import '../../models/user_business.dart';
import '../../repositories/quotes_repository.dart';
import '../auth/auth_providers.dart';

final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Usuário não autenticado.');
  return ref.watch(quotesRepositoryProvider).fetchAll(userId);
});

final businessProvider = FutureProvider<UserBusiness?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Usuário não autenticado.');
  return ref.watch(quotesRepositoryProvider).fetchBusiness(userId);
});
