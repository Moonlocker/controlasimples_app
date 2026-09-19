import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_controlasimples/widgets/async_error_view.dart';
import 'package:flutter_controlasimples/widgets/empty_state.dart';
import 'package:flutter_controlasimples/widgets/whatsapp_icon.dart';

void main() {
  testWidgets('EmptyState exibe título e descrição', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Nada por aqui',
            description: 'Descrição de teste',
          ),
        ),
      ),
    );

    expect(find.text('Nada por aqui'), findsOneWidget);
    expect(find.text('Descrição de teste'), findsOneWidget);
  });

  testWidgets('WhatsAppIcon renderiza sem erros', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WhatsAppIcon(size: 32))),
    );

    expect(find.byType(WhatsAppIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AsyncErrorView mostra mensagem amigável e ação', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncErrorView(
            error: Exception('SocketException: failed host lookup'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.textContaining('sem internet'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);
  });
}
