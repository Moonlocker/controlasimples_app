import '../../models/charge.dart';
import '../../models/notification.dart';
import '../../models/payment.dart';
import '../../models/workspace.dart';
import '../constants/enums.dart';
import 'dates.dart';
import 'formatters.dart';

ChargeStatus effectiveStatus(Charge charge, DateTime ref) {
  if (charge.status == ChargeStatus.pendente && charge.dueDate.isBefore(ref)) {
    return ChargeStatus.atrasado;
  }
  return charge.status;
}

class ChargeView {
  const ChargeView({
    required this.charge,
    required this.status,
    required this.clientName,
    this.serviceName,
  });

  final Charge charge;
  final ChargeStatus status;
  final String clientName;
  final String? serviceName;

  String get id => charge.id;
  String get clientId => charge.clientId;
  String? get serviceId => charge.serviceId;
  double get amount => charge.amount;
  DateTime get dueDate => charge.dueDate;
  String get description => charge.description;
}

List<ChargeView> chargeViews(Workspace workspace, [DateTime? ref]) {
  final reference = ref ?? today();
  final views = workspace.charges.map((charge) {
    return ChargeView(
      charge: charge,
      status: effectiveStatus(charge, reference),
      clientName: workspace.clientName(charge.clientId),
      serviceName: workspace.serviceName(charge.serviceId),
    );
  }).toList();
  views.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return views;
}

double _sum(Iterable<double> values) =>
    values.fold(0, (total, value) => total + value);

class FinanceMetrics {
  const FinanceMetrics({
    required this.receivedThisMonth,
    required this.toReceive,
    required this.overdue,
    required this.forecast30,
    required this.clients,
    required this.pendingCount,
    required this.overdueCount,
    required this.upcoming,
  });

  final double receivedThisMonth;
  final double toReceive;
  final double overdue;
  final double forecast30;
  final int clients;
  final int pendingCount;
  final int overdueCount;
  final List<ChargeView> upcoming;
}

FinanceMetrics computeMetrics(Workspace workspace, [DateTime? ref]) {
  final reference = ref ?? today();
  final views = chargeViews(workspace, reference);
  final currentMonth = monthKey(reference);

  final paidThisMonth = workspace.payments.where(
    (payment) => monthKey(payment.paidAt) == currentMonth,
  );
  final pending = views
      .where((view) => view.status == ChargeStatus.pendente)
      .toList();
  final overdue = views
      .where((view) => view.status == ChargeStatus.atrasado)
      .toList();
  final in30 = addMonths(reference, 1);

  return FinanceMetrics(
    receivedThisMonth: _sum(paidThisMonth.map((p) => p.amount)),
    toReceive: _sum(pending.map((v) => v.amount)),
    overdue: _sum(overdue.map((v) => v.amount)),
    forecast30:
        _sum(
          pending.where((v) => !v.dueDate.isAfter(in30)).map((v) => v.amount),
        ) +
        projectedRecurring(workspace, reference, in30),
    clients: workspace.clients.length,
    pendingCount: pending.length,
    overdueCount: overdue.length,
    upcoming: pending
        .where((v) => daysBetween(reference, v.dueDate) <= 15)
        .take(6)
        .toList(),
  );
}

double projectedRecurring(Workspace workspace, DateTime from, DateTime to) {
  var total = 0.0;
  for (final recurring in workspace.recurring.where((r) => r.active)) {
    final step = recurring.frequency.months;
    for (var i = 0; i < 600; i++) {
      final due = addMonths(recurring.startDate, i * step, recurring.dueDay);
      if (due.isAfter(to)) break;
      if (recurring.endDate != null && due.isAfter(recurring.endDate!)) break;
      if (due.isBefore(from)) continue;
      final exists = workspace.charges.any(
        (charge) =>
            charge.recurringId == recurring.id &&
            (charge.recurringDueDate ?? charge.dueDate) == due,
      );
      if (!exists) total += recurring.amount;
    }
  }
  return total;
}

class MonthPoint {
  const MonthPoint({
    required this.key,
    required this.received,
    required this.forecast,
  });

  final String key;
  final double received;
  final double forecast;
}

List<MonthPoint> monthlySeries(
  Workspace workspace, {
  int months = 6,
  DateTime? ref,
}) {
  final reference = ref ?? today();
  final views = chargeViews(workspace, reference);
  final points = <MonthPoint>[];
  for (var i = months - 1; i >= 0; i--) {
    final month = addMonths(DateTime(reference.year, reference.month), -i);
    final key = monthKey(month);
    final received = _sum(
      workspace.payments
          .where((p) => monthKey(p.paidAt) == key)
          .map((p) => p.amount),
    );
    final open = _sum(
      views
          .where(
            (v) =>
                monthKey(v.dueDate) == key &&
                (v.status == ChargeStatus.pendente ||
                    v.status == ChargeStatus.atrasado),
          )
          .map((v) => v.amount),
    );
    final nextMonth = addMonths(month, 1);
    points.add(
      MonthPoint(
        key: key,
        received: received,
        forecast: open + projectedRecurring(workspace, month, nextMonth),
      ),
    );
  }
  return points;
}

/// Série mensal entre [from] e [to] (inclusive), no mesmo formato do gráfico.
List<MonthPoint> monthPointsInRange(
  Workspace workspace,
  DateTime from,
  DateTime to,
) {
  final views = chargeViews(workspace);
  final points = <MonthPoint>[];
  var cursor = DateTime(from.year, from.month);
  final last = DateTime(to.year, to.month);
  var guard = 0;
  while (!cursor.isAfter(last) && guard < 600) {
    final key = monthKey(cursor);
    final received = _sum(
      workspace.payments
          .where((p) => monthKey(p.paidAt) == key)
          .map((p) => p.amount),
    );
    final open = _sum(
      views
          .where(
            (v) =>
                monthKey(v.dueDate) == key &&
                (v.status == ChargeStatus.pendente ||
                    v.status == ChargeStatus.atrasado),
          )
          .map((v) => v.amount),
    );
    final nextMonth = addMonths(cursor, 1);
    points.add(
      MonthPoint(
        key: key,
        received: received,
        forecast: open + projectedRecurring(workspace, cursor, nextMonth),
      ),
    );
    cursor = nextMonth;
    guard += 1;
  }
  return points;
}

class MonthBreakdownRow {
  const MonthBreakdownRow({
    required this.id,
    required this.received,
    required this.clientId,
    required this.clientName,
    this.serviceId,
    this.serviceName,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
    this.method,
    this.projected = false,
  });

  final String id;
  final bool received;
  final String clientId;
  final String clientName;
  final String? serviceId;
  final String? serviceName;
  final String description;
  final double amount;
  final DateTime date;
  final ChargeStatus status;
  final PaymentMethod? method;
  final bool projected;
}

class MonthBreakdown {
  const MonthBreakdown({required this.received, required this.open});

  final List<MonthBreakdownRow> received;
  final List<MonthBreakdownRow> open;
}

/// Cobranças/pagamentos de um mês ("yyyy-mm") com nomes resolvidos.
MonthBreakdown monthBreakdown(Workspace workspace, String key) {
  final views = chargeViews(workspace);

  final received = <MonthBreakdownRow>[];
  for (final payment in workspace.payments) {
    if (monthKey(payment.paidAt) != key) continue;
    final charge = workspace.chargeById(payment.chargeId);
    received.add(
      MonthBreakdownRow(
        id: payment.id,
        received: true,
        clientId: charge?.clientId ?? '',
        clientName: charge == null
            ? 'Cliente removido'
            : workspace.clientName(charge.clientId),
        serviceId: charge?.serviceId,
        serviceName: workspace.serviceName(charge?.serviceId),
        description: charge?.description ?? 'Pagamento registrado',
        amount: payment.amount,
        date: payment.paidAt,
        status: ChargeStatus.pago,
        method: payment.method,
      ),
    );
  }

  final open = <MonthBreakdownRow>[];
  for (final view in views) {
    if (monthKey(view.dueDate) != key) continue;
    if (view.status != ChargeStatus.pendente &&
        view.status != ChargeStatus.atrasado) {
      continue;
    }
    open.add(
      MonthBreakdownRow(
        id: view.id,
        received: false,
        clientId: view.clientId,
        clientName: view.clientName,
        serviceId: view.serviceId,
        serviceName: view.serviceName,
        description: view.description,
        amount: view.amount,
        date: view.dueDate,
        status: view.status,
      ),
    );
  }
  for (final occurrence in pendingRecurrencesForMonth(workspace, key)) {
    open.add(
      MonthBreakdownRow(
        id: 'g:${occurrence.recurringId}:${isoDate(occurrence.dueDate)}',
        received: false,
        clientId: occurrence.clientId,
        clientName: occurrence.clientName,
        serviceId: occurrence.serviceId,
        serviceName: occurrence.serviceName,
        description: occurrence.description,
        amount: occurrence.amount,
        date: occurrence.dueDate,
        status: ChargeStatus.pendente,
        projected: true,
      ),
    );
  }

  received.sort((a, b) => a.date.compareTo(b.date));
  open.sort((a, b) => a.date.compareTo(b.date));
  return MonthBreakdown(received: received, open: open);
}

class BreakdownItem {
  const BreakdownItem({required this.name, required this.value});

  final String name;
  final double value;
}

List<BreakdownItem> receivedByMethod(Iterable<Payment> payments) {
  final map = <PaymentMethod, double>{};
  for (final payment in payments) {
    map.update(
      payment.method,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  final items = map.entries
      .map((entry) => BreakdownItem(name: entry.key.label, value: entry.value))
      .toList();
  items.sort((a, b) => b.value.compareTo(a.value));
  return items;
}

List<BreakdownItem> receivedByClient(
  Workspace workspace,
  Iterable<Payment> payments,
) {
  final map = <String, double>{};
  for (final payment in payments) {
    final charge = workspace.chargeById(payment.chargeId);
    if (charge == null) continue;
    map.update(
      charge.clientId,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  final items = map.entries
      .map(
        (entry) => BreakdownItem(
          name: workspace.clientName(entry.key),
          value: entry.value,
        ),
      )
      .where((item) => item.value > 0)
      .toList();
  items.sort((a, b) => b.value.compareTo(a.value));
  return items.take(8).toList();
}

List<BreakdownItem> receivedByService(
  Workspace workspace,
  Iterable<Payment> payments,
) {
  final map = <String, double>{};
  for (final payment in payments) {
    final charge = workspace.chargeById(payment.chargeId);
    if (charge == null) continue;
    final key = charge.serviceId ?? '__none__';
    map.update(
      key,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  final items = map.entries
      .map(
        (entry) => BreakdownItem(
          name: entry.key == '__none__'
              ? 'Sem serviço'
              : (workspace.serviceName(entry.key) ?? '—'),
          value: entry.value,
        ),
      )
      .where((item) => item.value > 0)
      .toList();
  items.sort((a, b) => b.value.compareTo(a.value));
  return items.take(8).toList();
}

class RangeSummary {
  const RangeSummary({
    required this.received,
    required this.open,
    required this.overdue,
    required this.avgTicket,
    required this.paidCount,
    required this.totalCharges,
  });

  final double received;
  final double open;
  final double overdue;
  final double avgTicket;
  final int paidCount;
  final int totalCharges;

  double get receiveRate =>
      totalCharges == 0 ? 0 : (paidCount / totalCharges) * 100;
}

List<AppNotification> buildNotifications(Workspace workspace, [DateTime? ref]) {
  final reference = ref ?? today();
  final views = chargeViews(workspace, reference);
  final overdue = views
      .where((view) => view.status == ChargeStatus.atrasado)
      .toList();
  final soon = views
      .where(
        (view) =>
            view.status == ChargeStatus.pendente &&
            daysBetween(reference, view.dueDate) >= 0 &&
            daysBetween(reference, view.dueDate) <= 7,
      )
      .toList();
  final lastMonth = addMonths(reference, -1);
  final recentPaid =
      workspace.payments
          .where(
            (p) =>
                !p.paidAt.isBefore(lastMonth) && !p.paidAt.isAfter(reference),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final paidSlice = recentPaid.length > 6
      ? recentPaid.sublist(recentPaid.length - 6)
      : recentPaid;

  final list = <AppNotification>[];
  for (final payment in paidSlice) {
    final charge = workspace.chargeById(payment.chargeId);
    final clientName = charge == null
        ? '—'
        : workspace.clientName(charge.clientId);
    list.add(
      AppNotification(
        id: 'n_pag_${payment.id}',
        title: 'Pagamento recebido: $clientName — ${brl(payment.amount)}',
        kind: NotificationKind.pago,
        createdAt: payment.paidAt,
      ),
    );
  }
  for (final view in overdue.take(5)) {
    list.add(
      AppNotification(
        id: 'n_atr_${view.id}',
        title:
            'Cobrança atrasada: ${view.clientName} — ${brl(view.amount)} · ${view.description}',
        kind: NotificationKind.atrasado,
        createdAt: view.dueDate,
      ),
    );
  }
  for (final view in soon.take(5)) {
    final days = daysBetween(reference, view.dueDate);
    final when = days == 0 ? 'hoje' : (days == 1 ? 'amanhã' : 'em $days dias');
    list.add(
      AppNotification(
        id: 'n_venc_${view.id}',
        title:
            'Vence $when: ${view.clientName} — ${brl(view.amount)} · ${view.description}',
        kind: NotificationKind.vencendo,
        createdAt: view.dueDate,
      ),
    );
  }
  if (overdue.isNotEmpty) {
    final total = _sum(overdue.map((view) => view.amount));
    list.add(
      AppNotification(
        id: 'n_resumo_atraso_${isoDate(reference)}',
        title: 'Você possui ${brl(total)} em cobranças atrasadas.',
        kind: NotificationKind.resumo,
        createdAt: reference,
      ),
    );
  }
  if (soon.isNotEmpty) {
    list.add(
      AppNotification(
        id: 'n_resumo_venc_${isoDate(reference)}',
        title: 'Existem ${soon.length} cobranças vencendo nos próximos 7 dias.',
        kind: NotificationKind.resumo,
        createdAt: reference,
      ),
    );
  }
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

String notificationTime(DateTime value) {
  final diff = daysBetween(value, today());
  if (diff <= 0) return 'hoje';
  if (diff == 1) return 'ontem';
  return 'há $diff dias';
}

class PendingOccurrence {
  const PendingOccurrence({
    required this.recurringId,
    required this.clientId,
    required this.clientName,
    this.serviceId,
    this.serviceName,
    required this.description,
    required this.amount,
    required this.dueDate,
  });

  final String recurringId;
  final String clientId;
  final String clientName;
  final String? serviceId;
  final String? serviceName;
  final String description;
  final double amount;
  final DateTime dueDate;

  Map<String, dynamic> toChargeMap(String userId) {
    return {
      'user_id': userId,
      'client_id': clientId,
      'project_id': serviceId,
      'recurring_id': recurringId,
      'recurring_due_date': isoDate(dueDate),
      'description': description,
      'amount': amount,
      'due_date': isoDate(dueDate),
      'status': ChargeStatus.pendente.wire,
    };
  }
}

List<PendingOccurrence> pendingOccurrencesInRange(
  Workspace workspace,
  DateTime from,
  DateTime to,
) {
  final out = <PendingOccurrence>[];
  for (final recurring in workspace.recurring.where((r) => r.active)) {
    final step = recurring.frequency.months;
    for (var i = 0; i < 600; i++) {
      final due = addMonths(recurring.startDate, i * step, recurring.dueDay);
      if (due.isAfter(to)) break;
      if (recurring.endDate != null && due.isAfter(recurring.endDate!)) break;
      if (due.isBefore(from)) continue;
      final exists = workspace.charges.any(
        (charge) =>
            charge.recurringId == recurring.id &&
            (charge.recurringDueDate ?? charge.dueDate) == due,
      );
      if (!exists) {
        out.add(
          PendingOccurrence(
            recurringId: recurring.id,
            clientId: recurring.clientId,
            clientName: workspace.clientName(recurring.clientId),
            serviceId: recurring.serviceId,
            serviceName: workspace.serviceName(recurring.serviceId),
            description: recurring.description,
            amount: recurring.amount,
            dueDate: due,
          ),
        );
      }
    }
  }
  out.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return out;
}

List<PendingOccurrence> pendingRecurrencesForMonth(
  Workspace workspace,
  String yearMonth,
) {
  final parts = yearMonth.split('-');
  final start = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  final end = DateTime(start.year, start.month + 1, 0);
  return pendingOccurrencesInRange(workspace, start, end);
}

String formatMoney(double value) => brl(value);
