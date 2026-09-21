import '../core/constants/enums.dart';
import '../core/utils/dates.dart';

class Charge {
  const Charge({
    required this.id,
    required this.userId,
    required this.clientId,
    this.serviceId,
    this.recurringId,
    this.recurringDueDate,
    this.notificationsEnabled,
    required this.description,
    this.amount = 0,
    required this.dueDate,
    this.status = ChargeStatus.pendente,
    this.asaasPaymentId,
    this.asaasInvoiceUrl,
    this.asaasBankSlipUrl,
    this.asaasPixPayload,
    this.asaasPixQrCode,
    this.asaasStatus,
    this.asaasBillingType,
    this.provider,
    this.providerPaymentId,
    this.providerStatus,
    this.providerInvoiceUrl,
    this.providerBankSlipUrl,
    this.providerPixPayload,
    this.providerPixQrCode,
    this.providerBillingType,
    this.paidDate,
    required this.createdAt,
  });

  static const String table = 'charges';

  final String id;
  final String userId;
  final String clientId;
  final String? serviceId;
  final String? recurringId;

  /// Data da ocorrência original da recorrência (não muda ao ajustar o
  /// vencimento), mantendo o vínculo mesmo com data/valor alterados.
  final DateTime? recurringDueDate;

  /// Override dos avisos automáticos desta cobrança (null = herda do cliente).
  final bool? notificationsEnabled;
  final String description;
  final double amount;
  final DateTime dueDate;
  final ChargeStatus status;
  final String? asaasPaymentId;
  final String? asaasInvoiceUrl;
  final String? asaasBankSlipUrl;
  final String? asaasPixPayload;
  final String? asaasPixQrCode;
  final String? asaasStatus;
  final String? asaasBillingType;

  /// Provedor de pagamento que emitiu a cobrança (asaas, mercadopago, ...).
  final String? provider;
  final String? providerPaymentId;
  final String? providerStatus;
  final String? providerInvoiceUrl;
  final String? providerBankSlipUrl;
  final String? providerPixPayload;
  final String? providerPixQrCode;
  final String? providerBillingType;
  final DateTime? paidDate;
  final DateTime createdAt;

  factory Charge.fromMap(Map<String, dynamic> map) {
    return Charge(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      clientId: map['client_id'] as String,
      serviceId: map['project_id'] as String?,
      recurringId: map['recurring_id'] as String?,
      recurringDueDate: tryParseDate(map['recurring_due_date']),
      notificationsEnabled: map['notifications_enabled'] as bool?,
      description: (map['description'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDate: parseDate(map['due_date']),
      status: ChargeStatus.fromWire(map['status'] as String?),
      asaasPaymentId: map['asaas_payment_id'] as String?,
      asaasInvoiceUrl: map['asaas_invoice_url'] as String?,
      asaasBankSlipUrl: map['asaas_bank_slip_url'] as String?,
      asaasPixPayload: map['asaas_pix_payload'] as String?,
      asaasPixQrCode: map['asaas_pix_qr_code'] as String?,
      asaasStatus: map['asaas_status'] as String?,
      asaasBillingType: map['asaas_billing_type'] as String?,
      provider:
          (map['payment_provider'] as String?) ??
          (map['asaas_payment_id'] != null ? 'asaas' : null),
      providerPaymentId:
          (map['provider_payment_id'] as String?) ??
          map['asaas_payment_id'] as String?,
      providerStatus:
          (map['provider_status'] as String?) ?? map['asaas_status'] as String?,
      providerInvoiceUrl:
          (map['provider_invoice_url'] as String?) ??
          map['asaas_invoice_url'] as String?,
      providerBankSlipUrl:
          (map['provider_bank_slip_url'] as String?) ??
          map['asaas_bank_slip_url'] as String?,
      providerPixPayload:
          (map['provider_pix_payload'] as String?) ??
          map['asaas_pix_payload'] as String?,
      providerPixQrCode:
          (map['provider_pix_qr_code'] as String?) ??
          map['asaas_pix_qr_code'] as String?,
      providerBillingType:
          (map['provider_billing_type'] as String?) ??
          map['asaas_billing_type'] as String?,
      paidDate: tryParseDate(map['paid_date']),
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap(String userId) {
    return {
      'user_id': userId,
      'client_id': clientId,
      'project_id': serviceId,
      'recurring_id': recurringId,
      'recurring_due_date': recurringDueDate == null
          ? null
          : isoDate(recurringDueDate!),
      'description': description,
      'amount': amount,
      'due_date': isoDate(dueDate),
      'status': status.wire,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'client_id': clientId,
      'project_id': serviceId,
      'description': description,
      'amount': amount,
      'due_date': isoDate(dueDate),
      'status': status.wire,
    };
  }
}
