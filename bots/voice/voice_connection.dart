import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:nyxx/nyxx.dart';

import 'audio_player.dart';
import '../../utils/ip_discovery.dart';

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

  Future<AudioPlayer?> getPlayer() async {
    var address = InternetAddress(udpProps['d']['ip'] as String);
    var port = udpProps['d']['port'] as int;
    var ssrc = udpProps['d']['ssrc'] as int;

    // IP discovery to get actual external IP address using Discord Protocol
    final ipInfo = await ipDiscovery(
      address: address,
      port: port,
      ssrc: ssrc,
    );

    if (ipInfo == null || ipInfo.address == null) {
      print('Error retrieving external IP and port.');
      return null;
    }

    var encMode = EncryptionMode.xSalsa20Poly1305;
    selectProtocol(
      Protocol.udp,
      ipInfo.address!,
      ipInfo.port,
      encryptionMode: encMode,
    );

    var sessionDescription = json.decode(await voiceStream.first as String);

    // we need this to encrypt the audio data
    var secretKey = (sessionDescription['d']['secret_key'] as List).cast<int>();

    // the actual player
    return await AudioPlayer.init(
      key: secretKey,
      connection: this,
      ssrc: ssrc,
      encryptionMode: encMode,
      remoteAddress: address,
      remotePort: port,
      localPort: ipInfo.port,
    );
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
    Protocol protocol,
    InternetAddress externalIp,
    int port, {
    EncryptionMode encryptionMode = EncryptionMode.xSalsa20Poly1305,
  }) {
    final udpConnPayload = {
      'op': 1,
      'd': {
        'protocol': _protocolToString(protocol),
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

  String _protocolToString(Protocol proto) {
    switch (proto) {
      case Protocol.udp:
        return 'udp';
      case Protocol.tcp:
        return 'tcp';
      default:
        throw UnimplementedError();
    }
  }
}

enum Protocol { udp, tcp }

enum EncryptionMode {
  aeadAesGcm,
  xSalsa20Poly1305,
  xSalsa20Poly1305Lite,
  xSalsa20Poly1305Suffix
}
