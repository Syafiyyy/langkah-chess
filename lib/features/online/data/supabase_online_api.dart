import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/server_clock.dart';
import '../../play_ai/domain/time_control.dart';
import '../domain/server_game.dart';
import 'online_api.dart';

/// [OnlineApi] on Supabase. Every request has a timeout, so a dead mobile
/// connection becomes [OnlineUnavailable] instead of hanging.
class SupabaseOnlineApi implements OnlineApi {
  SupabaseOnlineApi(this._client, this._clock);

  final SupabaseClient _client;
  final ServerClock _clock;

  static const Duration _timeout = Duration(seconds: 10);

  @override
  String get userId => _client.auth.currentUser!.id;

  @override
  Future<ServerGame> createInvite(TimeControl tc) =>
      _gameRpc('create_invite', _tc(tc));

  @override
  Future<ServerGame> joinInvite(String code) =>
      _gameRpc('join_invite', {'p_code': code});

  @override
  Future<ServerGame?> joinQueue(TimeControl tc) async {
    final rows = await _call(
      () => _client.rpc<List<dynamic>>('join_queue', params: _tc(tc)),
    );
    return rows.isEmpty
        ? null
        : ServerGame.fromRow(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> leaveQueue() => _call(() => _client.rpc<void>('leave_queue'));

  @override
  Future<ServerGame> fetchGame(String gameId) async {
    final row = await _call(
      () => _client.from('games').select().eq('id', gameId).maybeSingle(),
    );
    if (row == null) throw const OnlineRejected('NOT_FOUND');
    return ServerGame.fromRow(row);
  }

  @override
  Future<List<ServerMove>> fetchMoves(String gameId, {int afterPly = 0}) async {
    final rows = await _call(
      () => _client
          .from('moves')
          .select('ply, uci, san, fen_after')
          .eq('game_id', gameId)
          .gt('ply', afterPly)
          // postgrest-dart orders descending unless told otherwise.
          .order('ply', ascending: true),
    );
    return rows.map(ServerMove.fromRow).toList();
  }

  @override
  Future<MoveResponse> makeMove({
    required String gameId,
    required int ply,
    required String uci,
    required String clientMoveId,
  }) async {
    try {
      final res = await _client.functions
          .invoke(
            'make_move',
            body: {
              'game_id': gameId,
              'ply': ply,
              'uci': uci,
              'client_move_id': clientMoveId,
            },
          )
          .timeout(_timeout);
      final data = res.data as Map<String, dynamic>;
      final serverNow = _serverNow(data);
      return MoveResponse(
        game: ServerGame.fromRow(data['game'] as Map<String, dynamic>),
        applied: data['applied'] as bool,
        serverNow: serverNow,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map<String, dynamic>) _serverNow(details);
      if (e.status >= 400 && e.status < 500 && details is Map) {
        throw OnlineRejected(details['error'] as String? ?? 'HTTP_${e.status}');
      }
      throw OnlineUnavailable(e);
    } on TimeoutException catch (e) {
      throw OnlineUnavailable(e);
    } on Exception catch (e) {
      throw OnlineUnavailable(e);
    }
  }

  DateTime? _serverNow(Map<String, dynamic> body) {
    final raw = body['server_now'] as String?;
    final t = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    if (t != null) _clock.addPreciseSample(t);
    return t;
  }

  @override
  Future<ServerGame> act(GameAction action, String gameId) => _gameRpc(
    switch (action) {
      GameAction.resign => 'resign',
      GameAction.offerDraw => 'offer_draw',
      GameAction.acceptDraw => 'accept_draw',
      GameAction.declineDraw => 'decline_draw',
      GameAction.abort => 'abort',
      GameAction.claimTimeout => 'claim_timeout',
    },
    {'p_game': gameId},
  );

  @override
  Future<ServerGame> offerRematch(String gameId) =>
      _gameRpc('offer_rematch', {'p_game': gameId});

  @override
  Future<Map<String, PlayerInfo>> players(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final rows = await _call(
      () => _client
          .from('profiles')
          .select('id, username, rating')
          .inFilter('id', list),
    );
    return {
      for (final r in rows)
        r['id'] as String: PlayerInfo(
          username: r['username'] as String,
          rating: r['rating'] as int,
        ),
    };
  }

  @override
  Future<int?> ratingChange(String gameId) async {
    final row = await _call(
      () => _client
          .from('rating_history')
          .select('before, after')
          .eq('game_id', gameId)
          .eq('user_id', userId)
          .maybeSingle(),
    );
    if (row == null) return null;
    return (row['after'] as int) - (row['before'] as int);
  }

  @override
  Future<ServerGame?> activeGame() async {
    final uid = userId;
    final rows = await _call(
      () => _client
          .from('games')
          .select()
          .eq('status', 'active')
          .or('white_id.eq.$uid,black_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(1),
    );
    return rows.isEmpty ? null : ServerGame.fromRow(rows.first);
  }

  @override
  Future<List<ServerGame>> finishedGames({int limit = 50}) async {
    final uid = userId;
    final rows = await _call(
      () => _client
          .from('games')
          .select()
          .eq('status', 'finished')
          .or('white_id.eq.$uid,black_id.eq.$uid')
          .order('finished_at', ascending: false)
          .limit(limit),
    );
    return rows.map(ServerGame.fromRow).toList();
  }

  @override
  Subscription watchGame(
    String gameId, {
    required void Function() onHint,
    required void Function(bool connected) onConnected,
  }) {
    final channel = _client
        .channel('game:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: gameId,
          ),
          callback: (_) => onHint(),
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('Realtime game:$gameId $status $error');
          onConnected(status == RealtimeSubscribeStatus.subscribed);
        });
    return _ChannelSubscription(_client, channel);
  }

  @override
  Subscription watchMyGames({required void Function() onHint}) {
    final uid = userId;
    var channel = _client.channel('my-games:$uid');
    for (final column in ['white_id', 'black_id']) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'games',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: uid,
        ),
        callback: (_) => onHint(),
      );
    }
    return _ChannelSubscription(_client, channel.subscribe());
  }

  Future<ServerGame> _gameRpc(String fn, Map<String, dynamic> params) async {
    final row = await _call(
      () => _client.rpc<Map<String, dynamic>>(fn, params: params),
    );
    return ServerGame.fromRow(row);
  }

  static Map<String, dynamic> _tc(TimeControl tc) => {
    'p_time_base_ms': tc.initial.inMilliseconds,
    'p_increment_ms': tc.increment.inMilliseconds,
  };

  /// Maps errors: an RPC's own error code (raised as SQLSTATE P0001) is a
  /// rejection; anything else (network, timeout, 5xx) is unavailability.
  static Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw OnlineRejected(e.message);
      // The function isn't deployed (e.g. a migration not pushed yet).
      if (e.code == 'PGRST202') throw const OnlineRejected('NOT_DEPLOYED');
      throw OnlineUnavailable(e);
    } on OnlineFailure {
      rethrow;
    } on Exception catch (e) {
      throw OnlineUnavailable(e);
    }
  }
}

class _ChannelSubscription implements Subscription {
  _ChannelSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  void cancel() => unawaited(_client.removeChannel(_channel));
}
