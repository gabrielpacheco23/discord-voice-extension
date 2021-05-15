import 'package:nyxx/nyxx.dart';
import '../voice/audio_player.dart';
import '../../voice_extension.dart';

const botToken = r'****************************************************';

void main() async {
  var bot = Nyxx(botToken, GatewayIntents.allUnprivileged);
  AudioPlayer? player;

  bot.onMessageReceived.listen((event) async {
    if (event.message.content.startsWith('.')) {
      var channel = (event.message as GuildMessage)
          .member
          .voiceState
          ?.channel
          ?.getFromCache();

      if (channel == null) {
        return;
      }

      final audioPath = event.message.content.substring(1);
      if (player == null) {
        // joins channel
        player = await (channel as VoiceGuildChannel).join();
        // plays audio
        await player?.playFFmpeg(audioPath);
      } else {
        await player?.playFFmpeg(audioPath);
      }
    }
  });
}
