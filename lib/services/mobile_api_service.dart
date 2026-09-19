import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import 'supabase_service.dart';

final mobileApiServiceProvider = Provider<MobileApiService>((ref) {
  return MobileApiService(ref.watch(supabaseProvider), http.Client());
});

class MobileApiException implements Exception {
  MobileApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MobileApiService {
  MobileApiService(this._supabase, this._http);

  final SupabaseClient _supabase;
  final http.Client _http;

  Map<String, String> _headers({bool json = false}) {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      if (token != null) 'authorization': 'Bearer $token',
      if (json) 'content-type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
    }
    final Map<String, dynamic> data = switch (decoded) {
      Map<String, dynamic>() => decoded,
      Map() => Map<String, dynamic>.from(decoded),
      _ => <String, dynamic>{},
    };
    final error = data['error'];
    if (response.statusCode >= 400 || error != null) {
      throw MobileApiException(
        error?.toString() ?? _statusMessage(response.statusCode),
      );
    }
    if (decoded == null && body.isNotEmpty) {
      throw MobileApiException(
        'Não foi possível concluir a solicitação. Tente novamente.',
      );
    }
    return data;
  }

  /// Mensagem amigável (sem códigos) para falhas sem corpo de erro do servidor.
  String _statusMessage(int status) {
    if (status == 401) {
      return 'Sua sessão expirou. Entre novamente para continuar.';
    }
    if (status == 403) {
      return 'Você não tem permissão para fazer isso.';
    }
    if (status == 404) {
      return 'Não encontramos essas informações.';
    }
    if (status >= 500) {
      return 'Nosso serviço está temporariamente indisponível. '
          'Tente novamente em alguns instantes.';
    }
    return 'Não foi possível concluir a solicitação. Tente novamente.';
  }

  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final response = await _http.get(uri, headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await _http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(json: true),
      body: jsonEncode(body ?? const {}),
    );
    return _decode(response);
  }
}
