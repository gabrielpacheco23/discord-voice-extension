import 'dart:io';
import 'dart:typed_data';

import '../gangbot/ffmpeg/ffmpeg.dart';
import 'silence_packet.dart';
import 'voice_connection.dart';
import '../../utils/encryption.dart';
import 'voice_packet.dart';

// maybe will change the name of this class later to better fit its purpose
class AudioPlayer {
  final List<int> key;
  final VoiceConnection connection;
  final Encryption secretBox;
  final EncryptionMode encryptionMode;

  final RawDatagramSocket udpSocket;
  final InternetAddress remoteAddress;
  final int remotePort, localPort;
  final int ssrc;

  final dirPath = '/home/gabriel/Documents/dartprojs/gdp/audios/';

  var stopped = false;

  AudioPlayer._({
    required this.key,
    required this.connection,
    required this.secretBox,
    required this.remoteAddress,
    required this.remotePort,
    required this.localPort,
    required this.udpSocket,
    required this.ssrc,
    required this.encryptionMode,
  });

  static Future<AudioPlayer> init({
    required InternetAddress remoteAddress,
    required int remotePort,
    required int localPort,
    required List<int> key,
    required VoiceConnection connection,
    required int ssrc,
    EncryptionMode encryptionMode = EncryptionMode.xSalsa20Poly1305,
  }) async {
    final encryption = _getEncryption(encryptionMode);
    final secretBox = await encryption.init();

    final udpSock =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, localPort);
    return AudioPlayer._(
      key: key,
      connection: connection,
      secretBox: secretBox,
      encryptionMode: encryptionMode,
      udpSocket: udpSock,
      remoteAddress: remoteAddress,
      localPort: localPort,
      remotePort: remotePort,
      ssrc: ssrc,
    );
  }

  Future<void> playFFmpeg(String path) async {
    connection.speaking(5, ssrc);
    await play(path);
    connection.stopSpeaking(ssrc);
  }

  Future<void> play(String path) async {
    const silence = SilencePacket();
    const silenceFrames = 5;
    try {
      VoicePacket.resetMetadata();
      var audioPath = '$dirPath$path.mp3';

      var playing = true;

      // control chunk size
      var chunkSize = 960;

      var audioStream = Ffmpeg.chunkedStdout(audioPath, chunkSize);
      await for (var chunk in audioStream) {
        // this may be wrong
        if (chunk[0] == 0) {
          connection.stopSpeaking(ssrc);
          for (var i = 0; i < silenceFrames; i++) {
            udpSocket.send(silence.buffer, remoteAddress, remotePort);
          }
          continue;
        }

        if (stopped) {
          break;
        }

        VoicePacket.incrementMetadata();

        var nonce = VoicePacket.generateNonce(ssrc);
        var secretKey = Uint8List.fromList(key);

        var encAudio = secretBox.encrypt(
          message: chunk,
          nonce: nonce,
          key: secretKey,
        );

        final voicePacket = VoicePacket(encAudio, ssrc: ssrc);
        // print(voicePacket.buffer);

        connection.speaking(5, ssrc);
        udpSocket.send(voicePacket.buffer, remoteAddress, remotePort);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // var audioPath = '$dirPath$path.ogg';
      // var audioBytes = File(audioPath).readAsBytesSync();

      // var nonce = VoicePacket.generateNonce(ssrc);
      // var secretKey = Uint8List.fromList(key);

      // var encAudio = secretBox.encrypt(
      //   message: audioBytes,
      //   nonce: nonce,
      //   key: secretKey,
      // );

      // final voicePacket = VoicePacket(encAudio, ssrc: ssrc);
      // print(voicePacket.buffer);

      // connection.speaking(5, ssrc);

      // udpSocket.send(voicePacket.buffer, remoteAddress, remotePort);
    } catch (e, st) {
      // TODO: handle error
      print('$e: $st');
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
