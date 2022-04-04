import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:executor/executor.dart';

import 'video_process.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Processing Tool',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isDragging = false;
  final Set<XFile> files = {};
  String? outputDirectory;
  bool _isRunning = false;
  double _fileProgress = 0.0;
  Duration? _timeRemaining;
  String? _currentFileName;

  Future<void> popupAlert(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runProcess() async {
    if (outputDirectory == null) {
      await popupAlert('No Output Folder', 'Please select an output folder');
      return;
    } else if (_isRunning == true) {
      return;
    } else {
      final executor = Executor(concurrency: 1);
      for (var file in files) {
        executor.scheduleTask(() async => processEachFile(file));
      }
      await executor.join(withWaiting: true);
      await executor.close();
      setState(() {
        _isRunning = false;
      });
      await popupAlert('Complete', 'Complete: Tool will now close');
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0);
    }
  }

  Future<void> processEachFile(XFile file) async {
    setState(() {
      _isRunning = true;
      _currentFileName = file.name;
      _fileProgress = 0;
    });
    if (kDebugMode) {
      print('$_isRunning - $_currentFileName - $_fileProgress');
    }
    var fileSplit = file.path.split(RegExp(r'\\|\/'));
    fileSplit.removeLast();
    final workingDirectory = Platform.isWindows ? fileSplit.join('\\') : fileSplit.join('/');
    await processVideo(
        workingDirectory, file.path, file.name, outputDirectory!, updateProgress, popupAlert);
  }

  void updateProgress(String totalFrames, String completedFrames) {
    final totalFramesNumeric = double.parse(totalFrames);
    final completedFramesNumeric = double.parse(completedFrames);
    final _previousProgress = _fileProgress;
    setState(() {
      _fileProgress = completedFramesNumeric / totalFramesNumeric;
      _timeRemaining = Duration(
          seconds:
              ((1 - _fileProgress) / ((_fileProgress - _previousProgress) * 2))
                  .round());
    });
    if (kDebugMode) {
      print(
          '$_fileProgress = $completedFrames / $totalFramesNumeric --- Remaining ${_timeRemaining.toString().split('.').first.padLeft(8, "0")}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processing Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            DropTarget(
              onDragDone: (details) =>
                  setState(() => files.addAll(details.files)),
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              child: Card(
                elevation: 2,
                color: _isDragging ? Colors.orange : Colors.orange[200],
                child: Container(
                  height: 100,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const Text('**Drag and Drop Files HERE**'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  ElevatedButton(
                    child: const Text('Start'),
                    onPressed: _runProcess,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                      onPressed: () async {
                        outputDirectory =
                            await FilePicker.platform.getDirectoryPath();
                        setState(() {});
                      },
                      child: const Text('Output Folder')),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(outputDirectory ?? 'Choose Output Folder...'),
                ],
              ),
            ),
            if (_isRunning)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: Row(children: [
                  Text('Processing: ${_currentFileName ?? 'unknown name'}'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: _fileProgress,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_timeRemaining
                      .toString()
                      .split('.')
                      .first
                      .padLeft(8, "0")),
                ]),
              ),
            //const SizedBox(height: 5),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: files.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 5,
                  color: Colors.grey,
                ),
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(files.elementAt(index).name),
                  subtitle: Text(files.elementAt(index).path),
                  leading: files.elementAt(index).name == _currentFileName
                      ? const CircularProgressIndicator()
                      : null,
                  trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          files.remove(files.elementAt(index));
                        });
                      },
                      icon: const Icon(Icons.delete),
                      iconSize: 20,
                      splashRadius: 20),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
