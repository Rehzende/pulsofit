import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../core/constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  
  factory WebSocketService() {
    return _instance;
  }
  
  WebSocketService._internal();
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect(String token) async {
    if (_isConnected) return;

    try {
      // Construct WS URL from HTTP base URL
      final baseUrl = AppConstants.baseUrl.replaceAll('http', 'ws');
      final wsUrl = '$baseUrl/ws/connect?token=$token';
      
      debugPrint('Connecting to WebSocket: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _eventController.add(data);
          } catch (e) {
            debugPrint('Error decoding WS message: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
        },
      );
      
      // Send initial online status
      sendEvent('ONLINE', {});
      
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      _isConnected = false;
    }
  }

  void sendEvent(String event, Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      final payload = jsonEncode({
        'event': event,
        'data': data,
      });
      _channel!.sink.add(payload);
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _isConnected = false;
    }
  }
  
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
