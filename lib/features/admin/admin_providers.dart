import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin.dart';
import '../../models/asaas.dart';
import '../../models/platform_billing.dart';
import '../../models/whatsapp_template.dart';
import '../../repositories/admin_repository.dart';

final adminDataProvider = FutureProvider<AdminData>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAdminData();
});

final adminAsaasConfigProvider = FutureProvider<AsaasConfig>((ref) {
  return ref.watch(adminRepositoryProvider).asaasAdminConfig();
});

final adminPlatformBillingConfigProvider =
    FutureProvider<PlatformBillingConfig>((ref) {
      return ref.watch(adminRepositoryProvider).platformBillingConfig();
    });

final adminPlatformSubscriptionsProvider =
    FutureProvider<List<PlatformSubscription>>((ref) {
      return ref.watch(adminRepositoryProvider).platformSubscriptions();
    });

final adminWhatsappConfigProvider = FutureProvider<WhatsappAdminConfig>((ref) {
  return ref.watch(adminRepositoryProvider).whatsappAdminConfig();
});

final adminWhatsappOverviewProvider = FutureProvider<WhatsappOverview>((ref) {
  return ref.watch(adminRepositoryProvider).whatsappOverview();
});

final adminMessagesProvider =
    FutureProvider.family<List<WhatsappMessage>, String?>((ref, userId) {
      return ref.watch(adminRepositoryProvider).fetchMessages(userId: userId);
    });

final adminWhatsappTemplatesProvider = FutureProvider<List<WhatsappTemplate>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).fetchWhatsappTemplates();
});

final adminMetaTemplatesProvider = FutureProvider<List<MetaWhatsappTemplate>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).fetchMetaWhatsappTemplates();
});
