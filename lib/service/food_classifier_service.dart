import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// URL model TFLite — disimpan di GitHub Releases agar tidak melebihi batas aset 5 MB
const _modelUrl =
    'https://github.com/kyyril/a758-machine-learning-flutter/releases/download/v1.0.0/1.tflite';

class FoodClassification {
  final String label;
  final double confidence;
  const FoodClassification({required this.label, required this.confidence});
}

/// Message sent to the isolate
class _IsolateMessage {
  final String modelPath;
  final String labelsPath;
  final String imagePath;
  final SendPort sendPort;
  const _IsolateMessage({
    required this.modelPath,
    required this.labelsPath,
    required this.imagePath,
    required this.sendPort,
  });
}

/// Top-level function that runs in the background isolate
void _inferenceIsolate(_IsolateMessage message) {
  try {
    final interpreter = Interpreter.fromFile(File(message.modelPath));
    final labelsContent = File(message.labelsPath).readAsStringSync();
    final labels = labelsContent.trim().split('\n');

    final imageBytes = File(message.imagePath).readAsBytesSync();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      message.sendPort.send({'error': 'Could not decode image'});
      return;
    }

    // Resize to 224x224 (model input size)
    final resized = img.copyResize(decoded, width: 224, height: 224);

    // Normalise pixel values to [0.0, 1.0]
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    );

    final outputCount = interpreter.getOutputTensor(0).shape[1];
    final output = List.filled(outputCount, 0.0).reshape([1, outputCount]);

    interpreter.run(input, output);
    interpreter.close();

    final scores = (output[0] as List).cast<double>();
    final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]))
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = indexed.take(5).map((e) {
      final labelName = e.key < labels.length ? labels[e.key] : 'Unknown';
      return {'label': labelName, 'confidence': e.value};
    }).toList();

    message.sendPort.send({'results': top5});
  } catch (e) {
    message.sendPort.send({'error': e.toString()});
  }
}

class FoodClassifierService {
  FoodClassifierService._();
  static final FoodClassifierService instance = FoodClassifierService._();

  /// Download model dari GitHub Releases jika belum ada di cache lokal.
  /// Public agar bisa diakses oleh halaman lain (mis. CameraStreamPage).
  Future<String> ensureModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/food_model.tflite');
    if (!modelFile.existsSync()) {
      // Download model dari GitHub Releases
      final response = await http.get(Uri.parse(_modelUrl));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh model (HTTP ${response.statusCode})');
      }
      await modelFile.writeAsBytes(response.bodyBytes);
    }
    return modelFile.path;
  }

  /// Runs inference on a background Isolate to keep UI responsive.
  Future<List<FoodClassification>> classify(String imagePath) async {
    final tempDir = Directory.systemTemp;

    // Model: download jika belum ada, lalu cache
    final modelPath = await ensureModel();

    // Labels: tetap dari asset (ukuran < 25 KB)
    final labelsData = await rootBundle.loadString('assets/probability-labels-en.txt');
    final labelsFile = File('${tempDir.path}/food_labels.txt');
    await labelsFile.writeAsString(labelsData);

    final receivePort = ReceivePort();
    await Isolate.spawn(
      _inferenceIsolate,
      _IsolateMessage(
        modelPath: modelPath,
        labelsPath: labelsFile.path,
        imagePath: imagePath,
        sendPort: receivePort.sendPort,
      ),
    );

    final result = await receivePort.first as Map<String, dynamic>;
    receivePort.close();

    if (result.containsKey('error')) {
      throw Exception(result['error']);
    }

    final rawResults = result['results'] as List;
    return rawResults
        .map(
          (e) => FoodClassification(
            label: (e as Map)['label'] as String,
            confidence: e['confidence'] as double,
          ),
        )
        .toList();
  }
}
