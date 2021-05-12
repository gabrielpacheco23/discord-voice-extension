import 'dart:io';
import 'dart:typed_data';

import 'silence_packet.dart';
import 'voice_connection.dart';
import '../../utils/encryption.dart';
import 'voice_packet.dart';

// holds information about UDP connection
// maybe will change the name of this class later to better fit its purpose
class AudioPlayer {
  final List<int> key;
  final VoiceConnection connection;
  final Encryption secretBox;
  final EncryptionMode encryptionMode;

  final RawDatagramSocket udpSocket;
  final InternetAddress udpAddress;
  final int udpPort;
  final int ssrc;

  final dirPath = '/home/gabriel/Documents/dartprojs/gdp/audios/';

  AudioPlayer._({
    required this.key,
    required this.connection,
    required this.secretBox,
    required this.udpSocket,
    required this.udpAddress,
    required this.udpPort,
    required this.ssrc,
    required this.encryptionMode,
  });

  static Future<AudioPlayer> init({
    required InternetAddress udpAddress,
    required int udpPort,
    required List<int> key,
    required VoiceConnection connection,
    required int ssrc,
    EncryptionMode encryptionMode = EncryptionMode.xSalsa20Poly1305,
  }) async {
    final enc = _getEncryption(encryptionMode);
    final encryption = await enc.init();

    final udpSock =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);

    return AudioPlayer._(
      key: key,
      connection: connection,
      secretBox: encryption,
      encryptionMode: encryptionMode,
      udpSocket: udpSock,
      udpAddress: udpAddress,
      udpPort: udpPort,
      ssrc: ssrc,
    );
  }

  Future<void> play(String path) async {
    try {
      // I dont know if we need to send silence packets when connected
      // const silence = SilencePacket();
      // udpSocket.send(silence.buffer, udpAddress, udpPort);

      var audioPath = '$dirPath$path.ogg';
      var audioBytes = File(audioPath).readAsBytesSync();

      var nonce = VoicePacket.generateNonce(ssrc);
      var secretKey = Uint8List.fromList(key);

      // encrypts using libsodium wrapper for Dart
      var encAudio = secretBox.encrypt(
        message: audioBytes,
        nonce: nonce,
        key: secretKey,
      );

      // voice packet with Real-time Transport Protocol header
      // and encrypted audio bytes
      final voicePacket = VoicePacket(encAudio, ssrc: ssrc);

      // sets speaking to true with voice priority
      connection.speaking(5, ssrc);

      // send the voice packet to connection UDP server
      udpSocket.send(voicePacket.buffer, udpAddress, udpPort);
    } catch (e) {
      // TODO: handle error
    } finally {
      udpSocket.close();
    }
  }

  static Encryption _getEncryption(EncryptionMode mode) {
    switch (mode) {
      case EncryptionMode.xSalsa20Poly1305:
      case EncryptionMode.xSalsa20Poly1305Lite:
      case EncryptionMode.xSalsa20Poly1305Suffix:
        return Encryption.xSalsa20Poly1305();

      case EncryptionMode.aeadAesGcm:
      default:
        throw UnimplementedError();
    }
  }
}
