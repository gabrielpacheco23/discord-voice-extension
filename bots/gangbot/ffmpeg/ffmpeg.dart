// import 'dart:convert';
import 'dart:io';

abstract class Ffmpeg {
  static String convert(String inputPath, {String? outputPath}) =>
      mp3ToOpus(inputPath, output: outputPath);
}

String mp3ToOpus(String input, {String? output}) {
  // var input = '/home/gabriel/Documents/dartprojs/gdp/cavalo';
  var outputPath = output;
  if (output == null) {
    outputPath = input.replaceAll('mp3', 'ogg');
  }

  // '-i', '$input.mp3', '-c:a', 'libopus', '$input.opus'
  Process.runSync('ffmpeg', [
    '-i',
    '$input',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-c:a',
    'libopus',
    '-b:a',
    '96k',
    // '-vbr',
    // 'on',
    // '-compression_level',
    // '10',
    // '-frame_duration',
    // ' 20',
    // '-application',
    // 'voip',
    '$outputPath',
  ]);

  return outputPath!;
}

void main() {
  var opusAudio =
      Ffmpeg.convert('/home/gabriel/Documents/dartprojs/gdp/audios/cavalo.mp3');
}
