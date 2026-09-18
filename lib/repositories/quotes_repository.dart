import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/enums.dart';
import '../core/utils/dates.dart';
import '../models/quote.dart';
import '../models/user_business.dart';
import '../services/supabase_service.dart';

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(supabaseProvider));
});

class QuotesRepository {
  QuotesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Quote>> fetchAll(String userId) async {
    final data = await _client
        .from(Quote.table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .whereType<Map>()
        .map((row) => Quote.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> save({
    String? id,
    required String userId,
    required String clientId,
    required String number,
    required String title,
    required DateTime issuedOn,
    DateTime? validUntil,
    QuoteStatus status = QuoteStatus.rascunho,
    String layout = 'moderno',
    String? note,
    required List<QuoteItem> items,
    required double subtotal,
    required double discount,
  }) async {
    final payload = {
      'client_id': clientId,
      'number': number,
      'title': title,
      'issued_on': isoDate(issuedOn),
      'valid_until': validUntil == null ? null : isoDate(validUntil),
      'status': status.wire,
      'layout': layout,
      'note': note,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
    };
    if (id == null) {
      await _client.from(Quote.table).insert({'user_id': userId, ...payload});
    } else {
      await _client.from(Quote.table).update(payload).eq('id', id);
    }
  }

  Future<void> setStatus(String id, QuoteStatus status) async {
    await _client
        .from(Quote.table)
        .update({'status': status.wire})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from(Quote.table).delete().eq('id', id);
  }

  Future<UserBusiness?> fetchBusiness(String userId) async {
    final data = await _client
        .from(UserBusiness.table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserBusiness.fromMap(data);
  }

  Future<void> saveBusiness({
    required String userId,
    String? logo,
    String? company,
    String? document,
    String? email,
    String? phone,
    String? address,
    String? paymentInfo,
    String? extraNote,
  }) async {
    await _client.from(UserBusiness.table).upsert({
      'user_id': userId,
      'logo': logo,
      'company': company,
      'document': document,
      'email': email,
      'phone': phone,
      'address': address,
      'payment_info': paymentInfo,
      'extra_note': extraNote,
    });
  }
}
