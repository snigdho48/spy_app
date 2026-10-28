import 'package:one_request/one_request.dart';
import 'package:spy_love/core/config/app_config.dart';
import 'package:spy_love/core/storage/token_storage.dart';

/// Live device events from the Django Channels endpoint via [OneRequest.socket].
class EventStreamClient {
  EventStreamClient(this._tokens);

  final TokenStorage _tokens;
  OneSocket? _socket;

  Future<void> listen(void Function(Map<String, dynamic> event) onEvent) async {
    await close();
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) return;

    final uri = Uri.parse(
      AppConfig.wsBaseUrl,
    ).replace(queryParameters: {'token': token});

    _socket = OneRequest.socket(
      url: uri.toString(),
      autoReconnect: true,
      headers: {'Authorization': 'Bearer $token'},
      onMessage: (message) {
        if (message is! Map) return;
        final map = Map<String, dynamic>.from(message);
        final type = map['type'];
        if (type != 'event' && type != 'device_status') return;
        onEvent(map);
      },
    );
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
  }
}
