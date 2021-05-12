import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:nyxx/nyxx.dart';

class VoiceConnection {
  final VoiceState state;
  late final WebSocket _serverSocket;
  late final Stream voiceStream;

  late var udpProps;

  VoiceConnection._(this.state, this._serverSocket)
      : voiceStream = _serverSocket.asBroadcastStream();

  static Future<VoiceConnection> connect({
    required String endpoint,
    required VoiceState state,
  }) async {
    final ws = await WebSocket.connect('wss://$endpoint?v=4');
    return VoiceConnection._(state, ws);
  }

  void identify(String serverId, String userId, String token) {
    final payload = {
      'op': 0,
      'd': {
        'server_id': serverId,
        'user_id': userId,
        'session_id': state.sessionId,
        'token': token
      }
    };
    _serverSocket.add(json.encode(payload));
  }

  Future<Timer> heartbeat() async {
    final hello = json.decode(await voiceStream.first as String);
    udpProps = json.decode(await voiceStream.first as String);

    final heartbeatInterval = hello['d']['heartbeat_interval'] as double;

    final secondsPart = heartbeatInterval ~/ 1000;
    final millisecondsPart = (heartbeatInterval - (secondsPart * 1000)).toInt();

    final heartbeatDuration = Duration(
      seconds: secondsPart,
      milliseconds: millisecondsPart,
    );

    return Timer.periodic(heartbeatDuration, (timer) {
      final payload = {'op': 3, 'd': math.Random().nextInt(1 << 32)};
      _serverSocket.add(json.encode(payload));
    });
  }

  void selectProtocol(
    String protocol,
    InternetAddress externalIp,
    int port, {
    EncryptionMode encryptionMode = EncryptionMode.xSalsa20Poly1305,
  }) {
    final udpConnPayload = {
      'op': 1,
      'd': {
        'protocol': protocol,
        'data': {
          'address': externalIp.address,
          'port': port,
          // 'mode': 'xsalsa20_poly1305'
          'mode': _encryptionModeToString(encryptionMode),
        }
      }
    };
    _serverSocket.add(json.encode(udpConnPayload));
  }

  void speaking(int flags, int ssrc) {
    final speakingPayload = {
      'op': 5,
      'd': {'speaking': 5, 'delay': 0, 'ssrc': ssrc}
    };
    _serverSocket.add(json.encode(speakingPayload));
  }

  void stopSpeaking(int ssrc) {
    final stoppedPayload = {
      'op': 5,
      'd': {
        'speaking': 0,
        'delay': 0,
        'ssrc': ssrc,
      }
    };
    _serverSocket.add(json.encode(stoppedPayload));
  }

  String _encryptionModeToString(EncryptionMode mode) {
    switch (mode) {
      case EncryptionMode.aeadAesGcm:
        return 'aead_aes256_gcm';
      case EncryptionMode.xSalsa20Poly1305:
        return 'xsalsa20_poly1305';
      case EncryptionMode.xSalsa20Poly1305Lite:
        return 'xsalsa20_poly1305_lite';
      case EncryptionMode.xSalsa20Poly1305Suffix:
        return 'xsalsa20_poly1305_suffix';
      default:
        throw Error(); // unreachable
    }
  }
}

enum EncryptionMode {
  aeadAesGcm,
  xSalsa20Poly1305,
  xSalsa20Poly1305Lite,
  xSalsa20Poly1305Suffix
}
