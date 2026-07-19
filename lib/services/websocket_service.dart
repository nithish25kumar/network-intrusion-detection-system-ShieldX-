import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/alert.dart';
import 'api_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<IdsAlert>.broadcast();

  Stream<IdsAlert> get alertStream => _controller.stream;

  void connect() {
    final wsUrl = kBackendBaseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/alerts'));
    _channel!.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message);
          if (decoded['type'] == 'alert') {
            _controller.add(IdsAlert.fromJson(decoded['data']));
          }
        } catch (_) {
          // ignore malformed frames
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_controller.isClosed) connect();
    });
  }

  void disconnect() {
    _channel?.sink.close();
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}
