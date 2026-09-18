import '../core/constants/enums.dart';
import 'charge.dart';
import 'client.dart';
import 'payment.dart';
import 'plan.dart';
import 'profile.dart';
import 'recurring_charge.dart';
import 'service.dart';
import 'subscription.dart';

class Workspace {
  const Workspace({
    this.clients = const [],
    this.services = const [],
    this.charges = const [],
    this.recurring = const [],
    this.payments = const [],
    this.profile,
    this.subscription,
    this.roles = const [],
    this.plans = const [],
  });

  final List<Client> clients;
  final List<Service> services;
  final List<Charge> charges;
  final List<RecurringCharge> recurring;
  final List<Payment> payments;
  final Profile? profile;
  final Subscription? subscription;
  final List<AppRole> roles;
  final List<Plan> plans;

  bool get isSuperadmin => roles.contains(AppRole.superadmin);

  bool get onboardingCompleted => profile?.onboardingCompleted ?? false;

  bool get canUseAsaas => plan?.allowAsaasIntegration ?? true;

  bool get canUseWhatsapp => plan?.allowWhatsappNotifications ?? true;

  Plan? get plan {
    final planId = subscription?.planId;
    if (planId == null) return null;
    for (final plan in plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  Client? clientById(String? id) {
    if (id == null) return null;
    for (final client in clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Service? serviceById(String? id) {
    if (id == null) return null;
    for (final service in services) {
      if (service.id == id) return service;
    }
    return null;
  }

  Charge? chargeById(String? id) {
    if (id == null) return null;
    for (final charge in charges) {
      if (charge.id == id) return charge;
    }
    return null;
  }

  String clientName(String? id) => clientById(id)?.name ?? '—';

  String? serviceName(String? id) => serviceById(id)?.name;
}
