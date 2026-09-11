enum ChargeStatus {
  pendente('pendente', 'Pendente'),
  pago('pago', 'Pago'),
  atrasado('atrasado', 'Atrasado'),
  cancelado('cancelado', 'Cancelado');

  const ChargeStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ChargeStatus fromWire(String? value) {
    return ChargeStatus.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => ChargeStatus.pendente,
    );
  }
}

enum ServiceStatus {
  negociacao('negociacao', 'Negociação'),
  andamento('andamento', 'Em andamento'),
  concluido('concluido', 'Concluído'),
  cancelado('cancelado', 'Cancelado');

  const ServiceStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ServiceStatus fromWire(String? value) {
    return ServiceStatus.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => ServiceStatus.negociacao,
    );
  }
}

enum ServiceBilling {
  unico('unico', 'Valor único'),
  recorrente('recorrente', 'Recorrente'),
  misto('misto', 'Misto');

  const ServiceBilling(this.wire, this.label);

  final String wire;
  final String label;

  static ServiceBilling fromWire(String? value) {
    return ServiceBilling.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => ServiceBilling.unico,
    );
  }
}

enum PaymentMethod {
  pix('pix', 'PIX'),
  transferencia('transferencia', 'Transferência'),
  dinheiro('dinheiro', 'Dinheiro'),
  cartao('cartao', 'Cartão'),
  boleto('boleto', 'Boleto'),
  outro('outro', 'Outro');

  const PaymentMethod(this.wire, this.label);

  final String wire;
  final String label;

  static PaymentMethod fromWire(String? value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => PaymentMethod.pix,
    );
  }
}

enum Recurrence {
  mensal('mensal', 'Mensal', 1),
  trimestral('trimestral', 'Trimestral', 3),
  semestral('semestral', 'Semestral', 6),
  anual('anual', 'Anual', 12);

  const Recurrence(this.wire, this.label, this.months);

  final String wire;
  final String label;
  final int months;

  static Recurrence fromWire(String? value) {
    return Recurrence.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => Recurrence.mensal,
    );
  }
}

enum QuoteStatus {
  rascunho('rascunho', 'Rascunho'),
  enviado('enviado', 'Enviado'),
  aprovado('aprovado', 'Aprovado'),
  recusado('recusado', 'Recusado');

  const QuoteStatus(this.wire, this.label);

  final String wire;
  final String label;

  static QuoteStatus fromWire(String? value) {
    return QuoteStatus.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => QuoteStatus.rascunho,
    );
  }
}

enum SubscriptionStatus {
  trial('trial', 'Período de teste'),
  ativa('ativa', 'Assinatura ativa'),
  cancelada('cancelada', 'Cancelada'),
  inadimplente('inadimplente', 'Pagamento pendente');

  const SubscriptionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static SubscriptionStatus fromWire(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.wire == value,
      orElse: () => SubscriptionStatus.trial,
    );
  }
}

enum AppRole {
  superadmin('superadmin'),
  user('user');

  const AppRole(this.wire);

  final String wire;

  static AppRole? fromWire(String? value) {
    for (final role in AppRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}
