import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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

  /// Runs inference on a background Isolate to keep UI responsive.
  Future<List<FoodClassification>> classify(String imagePath) async {
    // Write model and labels to temp files (Isolates cannot access Flutter assets)
    final tempDir = Directory.systemTemp;

    final modelData = await rootBundle.load('assets/1.tflite');
    final modelFile = File('${tempDir.path}/food_model.tflite');
    await modelFile.writeAsBytes(modelData.buffer.asUint8List());

    final labelsData = await rootBundle.loadString('assets/probability-labels-en.txt');
    final labelsFile = File('${tempDir.path}/food_labels.txt');
    await labelsFile.writeAsString(labelsData);

    final receivePort = ReceivePort();
    await Isolate.spawn(
      _inferenceIsolate,
      _IsolateMessage(
        modelPath: modelFile.path,
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
