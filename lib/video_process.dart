import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

Future<void> processVideo(String origFilepath, String fullFilePath, String origFile,
    String outputPath, Function updateProgress, Function popupA) async {
  final origFilename = origFile.split('.')[0];
  final current = p.current;
  //await popupA('Debug', current);
  final resultFrameCount = await Process.run(
    Platform.isWindows ? '$current\\ffprobe.exe' : 'ffprobe',
    [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=nb_frames',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      fullFilePath,
    ],
  );
  final frameCount = resultFrameCount.stdout as String;
  if (kDebugMode) {
    print(frameCount);
  }
//scrape video start timecode
  final resultTime = await Process.run(
    Platform.isWindows ? '$current\\ffprobe.exe' : 'ffprobe',
    [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream_tags=timecode',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      fullFilePath,
    ],
  );
  final timecode = resultTime.stdout as String;
  final timecodeSplit = timecode.split(':');
  final timecodeSplitMs = timecodeSplit.removeLast().trim().padRight(3, '0');
  final timecodeJoin = timecodeSplit.join(':') + '.' + timecodeSplitMs;
  if (kDebugMode) {
    print(timecodeJoin);
  }
//scrape video created datetime and remove time
  final resultCreation = await Process.run(
    Platform.isWindows ? '$current\\ffprobe.exe' : 'ffprobe',
    [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream_tags=creation_time',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      fullFilePath,
    ],
  );
  final creationTime = resultCreation.stdout as String;
  final videoDate = creationTime.split('T');
  if (kDebugMode) {
    print(videoDate);
  }
//piece together iso datetime string and parse
  final videoStartString = videoDate[0] + 'T' + timecodeJoin + 'Z';
  final videoStartDateTime = DateTime.parse(videoStartString);
  final videoStartEpoch = videoStartDateTime.millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;
//scrape duration
  final resultDuration = await Process.run(
    Platform.isWindows ? '$current\\ffprobe.exe' : 'ffprobe',
    [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'format=duration',
      '-sexagesimal',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      fullFilePath,
    ],
  );
  final durationString = resultDuration.stdout as String;
  final durationStringFormated = durationString.trim().padLeft(15, '0');
  final durationStringSplit = durationStringFormated.split(RegExp(r"\.|:"));
  final duration = Duration(
    hours: int.parse(durationStringSplit[0]),
    minutes: int.parse(durationStringSplit[1]),
    seconds: int.parse(durationStringSplit[2]),
    milliseconds: int.parse(durationStringSplit[3].substring(0, 3)),
  );
  final videoEndDateTime = videoStartDateTime.add(duration);
  if (kDebugMode) {
    print(duration);
    print('starting video process');
  }
  final pathCharacter = Platform.isWindows ? '\\' : '/';
  final process = await Process.start(
    Platform.isWindows ? '$current\\ffmpeg.exe' : 'ffmpeg',
    [
      '-progress',
      '-',
      '-nostats',
      '-y',
      '-i',
      fullFilePath,
      '-vf',
      'drawtext=\'box=1:boxcolor=0x000000@0.4:boxborderw=5:fontcolor=White:fontsize=56:x=(w-text_w-15):y=(h-text_h-15):text=%{pts\\:gmtime\\:$videoStartEpoch}\'',
      '-preset',
      'ultrafast',
      '-f',
      'mp4',
      '$outputPath$pathCharacter${DateFormat('y-MM-dd HH_mm_ss').format(videoStartDateTime)} to ${DateFormat('HH_mm_ss').format(videoEndDateTime)} - $origFilename.mp4'
    ],
  );
  if (kDebugMode) {
    print('after start');
    print(process.pid);
  }
   
     process.stdout.transform(utf8.decoder).forEach((out) => updateProgress(
      frameCount,
      out.split('\n')
          .firstWhere((element) => element.contains('frame'))
          .split('=')[1]
          .trim()));
  
      process.stderr.transform(utf8.decoder).forEach((err) => print(err));
  
  var exitCode = await process.exitCode;
  if (exitCode != 0){
    process.kill();
  }
}
