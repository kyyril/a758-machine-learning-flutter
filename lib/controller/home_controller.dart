import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:submission/ui/result_page.dart';
import 'package:submission/ui/camera_stream_page.dart';

class HomeController extends ChangeNotifier {
  File? _selectedImage;
  String? _error;

  File? get selectedImage => _selectedImage;
  String? get error => _error;

  final _picker = ImagePicker();

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  Future<void> pickFromGallery(BuildContext context) async {
    _setError(null);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      if (!context.mounted) return;
      await _cropAndNavigate(picked.path, context);
    } catch (e) {
      _setError('Gagal memilih gambar dari galeri.');
    }
  }

  Future<void> pickFromCamera(BuildContext context) async {
    _setError(null);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (picked == null) return;
      if (!context.mounted) return;
      await _cropAndNavigate(picked.path, context);
    } catch (e) {
      _setError('Gagal mengambil gambar dari kamera.');
    }
  }

  Future<void> _cropAndNavigate(String imagePath, BuildContext context) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Gambar',
          toolbarColor: const Color(0xFF2D7D46),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Gambar'),
      ],
    );
    if (cropped == null) return;

    _selectedImage = File(cropped.path);
    notifyListeners();

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(imageFile: _selectedImage!),
        ),
      );
    }
  }

  void openCameraStream(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraStreamPage()),
    );
  }
}
