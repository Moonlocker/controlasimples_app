import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_controlasimples/core/utils/error_messages.dart';

void main() {
  group('friendlyError', () {
    test('traduz falha de conexão para mensagem simples', () {
      final message = friendlyError(
        Exception('SocketException: Failed host lookup: supabase.co'),
      );
      expect(message, contains('sem internet'));
      expect(message, isNot(contains('SocketException')));
    });

    test('identifica erro de conexão', () {
      expect(isOfflineError(Exception('SocketException: failed')), isTrue);
      expect(isOfflineError(Exception('permission denied')), isFalse);
    });

    test('traduz erro interno do servidor', () {
      expect(
        friendlyError(Exception('Erro 503')),
        contains('temporariamente indisponível'),
      );
    });

    test('traduz credenciais inválidas', () {
      expect(
        friendlyError(Exception('Invalid login credentials')),
        'E-mail ou senha inválidos.',
      );
    });

    test('nunca expõe link quebrado', () {
      final message = friendlyError(
        Exception('Resposta inválida de https://api.exemplo.com/x'),
      );
      expect(message, isNot(contains('http')));
    });

    test('repassa mensagem de negócio legível', () {
      expect(
        friendlyError(Exception('Limite de mensagens atingido')),
        'Limite de mensagens atingido',
      );
    });

    test('usa mensagem genérica quando vazio', () {
      expect(friendlyError(null), contains('Tente novamente'));
    });
  });
}
