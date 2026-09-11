import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin.dart';
import '../../models/asaas.dart';
import '../../repositories/admin_repository.dart';

final adminDataProvider = FutureProvider<AdminData>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAdminData();
});

final adminAsaasConfigProvider = FutureProvider<AsaasConfig>((ref) {
  return ref.watch(adminRepositoryProvider).asaasAdminConfig();
});

final adminWhatsappConfigProvider = FutureProvider<WhatsappAdminConfig>((ref) {
  return ref.watch(adminRepositoryProvider).whatsappAdminConfig();
});

final adminWhatsappOverviewProvider = FutureProvider<WhatsappOverview>((ref) {
  return ref.watch(adminRepositoryProvider).whatsappOverview();
});

final adminMessagesProvider = FutureProvider.family<List<WhatsappMessage>, String?>((ref, userId) {
  return ref.watch(adminRepositoryProvider).fetchMessages(userId: userId);
});
