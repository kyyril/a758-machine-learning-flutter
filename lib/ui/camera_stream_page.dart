import 'dart:io';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:submission/ui/result_page.dart';

class CameraStreamPage extends StatefulWidget {
  const CameraStreamPage({super.key});

  @override
  State<CameraStreamPage> createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _liveLabel;
  double? _liveConfidence;
  String? _error;

  // Temp files for isolate access
  String? _modelPath;
  String? _labelsPath;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadModelAssets();
    await _initCamera();
  }

  Future<void> _loadModelAssets() async {
    try {
      final tempDir = Directory.systemTemp;

      final modelData = await rootBundle.load('assets/1.tflite');
      final modelFile = File('${tempDir.path}/food_model.tflite');
      await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      _modelPath = modelFile.path;

      final labelsData = await rootBundle.loadString('assets/probability-labels-en.txt');
      final labelsFile = File('${tempDir.path}/food_labels.txt');
      await labelsFile.writeAsString(labelsData);
      _labelsPath = labelsFile.path;
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat model: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'Tidak ada kamera tersedia.');
        return;
      }
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      _cameraController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _cameraController!.startImageStream(_onCameraImage);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal inisialisasi kamera: $e');
    }
  }

  Future<void> _onCameraImage(CameraImage cameraImage) async {
    if (_isProcessing || _modelPath == null || _labelsPath == null) return;
    _isProcessing = true;

    try {
      final receivePort = ReceivePort();
      await Isolate.spawn(
        _streamInferenceIsolate,
        _StreamIsolateMessage(
          modelPath: _modelPath!,
          labelsPath: _labelsPath!,
          yuv420Planes: cameraImage.planes
              .map((p) => p.bytes)
              .toList(),
          width: cameraImage.width,
          height: cameraImage.height,
          sendPort: receivePort.sendPort,
        ),
      );

      final result = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      if (mounted && result.containsKey('label')) {
        setState(() {
          _liveLabel = result['label'] as String;
          _liveConfidence = result['confidence'] as double;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Capture current frame and navigate to ResultPage
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_isInitialized) return;
    try {
      await _cameraController!.stopImageStream();
      final photo = await _cameraController!.takePicture();
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(imageFile: File(photo.path)),
        ),
      );
      if (mounted) {
        _cameraController!.startImageStream(_onCameraImage);
      }
    } catch (e) {
      setState(() => _error = 'Gagal mengambil gambar: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera Stream')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Live Scan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Center(child: CameraPreview(_cameraController!)),
                // Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _LiveOverlay(
                    label: _liveLabel,
                    confidence: _liveConfidence,
                    onCapture: _captureAndAnalyze,
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ── Overlay widget ────────────────────────────────────────────────────────────

class _LiveOverlay extends StatelessWidget {
  final String? label;
  final double? confidence;
  final VoidCallback onCapture;

  const _LiveOverlay({this.label, this.confidence, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7D46),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${((confidence ?? 0) * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ] else
            const Text('Arahkan kamera ke makanan...', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCapture,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7D46),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Analisis Makanan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ── Isolate message & entry point ─────────────────────────────────────────────

class _StreamIsolateMessage {
  final String modelPath;
  final String labelsPath;
  final List<Uint8List> yuv420Planes;
  final int width;
  final int height;
  final SendPort sendPort;

  _StreamIsolateMessage({
    required this.modelPath,
    required this.labelsPath,
    required this.yuv420Planes,
    required this.width,
    required this.height,
    required this.sendPort,
  });
}

void _streamInferenceIsolate(_StreamIsolateMessage msg) {
  try {
    // Convert YUV420 to RGB image
    final yPlane = msg.yuv420Planes[0];
    final uPlane = msg.yuv420Planes[1];
    final vPlane = msg.yuv420Planes[2];
    final w = msg.width;
    final h = msg.height;

    final image = img.Image(width: w, height: h);
    for (int j = 0; j < h; j++) {
      for (int i = 0; i < w; i++) {
        final y = yPlane[j * w + i];
        final uvIdx = (j ~/ 2) * (w ~/ 2) + (i ~/ 2);
        final u = uPlane[uvIdx];
        final v = vPlane[uvIdx];
        final r = (y + 1.402 * (v - 128)).clamp(0, 255).toInt();
        final g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).clamp(0, 255).toInt();
        final b = (y + 1.772 * (u - 128)).clamp(0, 255).toInt();
        image.setPixelRgb(i, j, r, g, b);
      }
    }

    final resized = img.copyResize(image, width: 224, height: 224);

    final interpreter = Interpreter.fromFile(File(msg.modelPath));
    final labels = File(msg.labelsPath).readAsStringSync().trim().split('\n');

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
    int bestIdx = 0;
    double bestScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIdx = i;
      }
    }

    msg.sendPort.send({
      'label': bestIdx < labels.length ? labels[bestIdx] : 'Unknown',
      'confidence': bestScore,
    });
  } catch (e) {
    msg.sendPort.send({'error': e.toString()});
  }
}
