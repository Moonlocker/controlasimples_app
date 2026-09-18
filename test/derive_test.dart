import 'package:flutter_controlasimples/core/constants/enums.dart';
import 'package:flutter_controlasimples/core/utils/derive.dart';
import 'package:flutter_controlasimples/models/charge.dart';
import 'package:flutter_controlasimples/models/client.dart';
import 'package:flutter_controlasimples/models/recurring_charge.dart';
import 'package:flutter_controlasimples/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Charge charge({
  required String id,
  required String clientId,
  required double amount,
  required DateTime dueDate,
  ChargeStatus status = ChargeStatus.pendente,
  String? recurringId,
}) {
  return Charge(
    id: id,
    userId: 'u1',
    clientId: clientId,
    description: 'Cobrança $id',
    amount: amount,
    dueDate: dueDate,
    status: status,
    recurringId: recurringId,
    createdAt: DateTime(2026, 1, 1),
  );
}

Client client({required String id, required String name}) {
  return Client(
    id: id,
    userId: 'u1',
    name: name,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final ref = DateTime(2026, 9, 10);

  test('marca cobrança pendente vencida como atrasada', () {
    final overdue = charge(
      id: 'c1',
      clientId: 'cl1',
      amount: 100,
      dueDate: DateTime(2026, 9, 1),
    );
    final future = charge(
      id: 'c2',
      clientId: 'cl1',
      amount: 100,
      dueDate: DateTime(2026, 9, 20),
    );
    expect(effectiveStatus(overdue, ref), ChargeStatus.atrasado);
    expect(effectiveStatus(future, ref), ChargeStatus.pendente);
  });

  test('computeMetrics soma recebido, a receber e atrasado', () {
    final workspace = Workspace(
      clients: [client(id: 'cl1', name: 'Cliente')],
      charges: [
        charge(
          id: 'c1',
          clientId: 'cl1',
          amount: 100,
          dueDate: DateTime(2026, 9, 5),
        ),
        charge(
          id: 'c2',
          clientId: 'cl1',
          amount: 200,
          dueDate: DateTime(2026, 9, 20),
        ),
        charge(
          id: 'c3',
          clientId: 'cl1',
          amount: 50,
          dueDate: DateTime(2026, 8, 1),
          status: ChargeStatus.pago,
        ),
      ],
    );

    final metrics = computeMetrics(workspace, ref);
    expect(metrics.overdue, 100);
    expect(metrics.toReceive, 200);
    expect(metrics.overdueCount, 1);
    expect(metrics.pendingCount, 1);
  });

  test('pendingOccurrencesInRange gera todas as ocorrências do período', () {
    final workspace = Workspace(
      clients: [client(id: 'cl1', name: 'Cliente')],
      recurring: [
        RecurringCharge(
          id: 'r1',
          userId: 'u1',
          clientId: 'cl1',
          description: 'Mensalidade',
          amount: 90,
          frequency: Recurrence.mensal,
          dueDay: 10,
          startDate: DateTime(2026, 1, 10),
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final pending = pendingOccurrencesInRange(
      workspace,
      DateTime(2026, 9, 1),
      DateTime(2026, 11, 30),
    );

    expect(pending.length, 3);
    expect(pending.first.dueDate, DateTime(2026, 9, 10));
    expect(pending.last.dueDate, DateTime(2026, 11, 10));
  });
}
