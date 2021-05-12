import 'dart:io';
import 'dart:convert';
import 'package:nyxx/nyxx.dart';

import 'bots/voice/audio_player.dart';
import 'bots/voice/voice_connection.dart';
import 'utils/ip_discovery.dart';

extension VoiceExt on VoiceGuildChannel {
  // joins the channel returning an AudioPlayer object
  // this method is working fine
  Future<AudioPlayer?> join() async {
    connect();

    try {
      final voiceStateData = await (client as Nyxx).onVoiceStateUpdate.first;
      final voiceServerData = await (client as Nyxx).onVoiceServerUpdate.first;

      final token = voiceServerData.token;
      final endpoint = voiceServerData.endpoint;
      final serverId = guild.id.toString();
      final userId = (client as Nyxx).self.id.toString();

      // makes websocket connection and sends the Discord's Voice Protocol methods
      final voiceConn = await VoiceConnection.connect(
        endpoint: endpoint,
        state: voiceStateData.state,
      );

      voiceConn.identify(serverId, userId, token);

      await voiceConn.heartbeat();

      var udpProps = voiceConn.udpProps;

      var address = InternetAddress(udpProps['d']['ip'] as String);
      var port = udpProps['d']['port'] as int;
      var ssrc = udpProps['d']['ssrc'] as int;

      // IP discovery to get actual external IP address using Discord Protocol
      final externalIp =
          await ipDiscovery(address: address, port: port, ssrc: ssrc);

      if (externalIp == null) {
        print('Error retrieving external IP');
        return null;
      }

      var encMode = EncryptionMode.xSalsa20Poly1305;
      voiceConn.selectProtocol(
        'udp',
        externalIp,
        port,
        encryptionMode: encMode,
      );

      var sessionDescription =
          json.decode(await voiceConn.voiceStream.first as String);

      // we need this to encrypt the audio data
      var secretKey =
          (sessionDescription['d']['secret_key'] as List).cast<int>();

      // the actual player
      return await AudioPlayer.init(
        udpAddress: address,
        udpPort: port,
        key: secretKey,
        connection: voiceConn,
        ssrc: ssrc,
        encryptionMode: encMode,
      );
    } catch (e, st) {
      print(e.toString());
      print(st.toString());
      return null;
    }
  }
}
