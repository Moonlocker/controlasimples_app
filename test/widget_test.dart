import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_controlasimples/widgets/empty_state.dart';

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
}
