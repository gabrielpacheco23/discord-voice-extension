import 'package:nyxx/nyxx.dart';

import 'bots/voice/audio_player.dart';
import 'bots/voice/voice_connection.dart';

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

      final voiceConn = await VoiceConnection.connect(
        endpoint: endpoint,
        state: voiceStateData.state,
      );

      voiceConn.identify(serverId, userId, token);
      await voiceConn.heartbeat();

      return await voiceConn.getPlayer();
    } catch (e, st) {
      print('$e: $st');
      return null;
    }
  }
}
