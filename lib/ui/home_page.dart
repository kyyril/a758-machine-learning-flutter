import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:submission/controller/home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D7D46),
        foregroundColor: Colors.white,
        title: const Text(
          'Food Recognizer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Hero image / selected image preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: controller.selectedImage != null
                      ? Image.file(
                          controller.selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : const _PlaceholderHero(),
                ),
              ),
              const SizedBox(height: 24),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    controller.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Buttons
              _ActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Pilih dari Galeri',
                color: const Color(0xFF2D7D46),
                onTap: () => controller.pickFromGallery(context),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Ambil Foto (Camera)',
                color: const Color(0xFF1565C0),
                onTap: () => controller.pickFromCamera(context),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.videocam_rounded,
                label: 'Camera Stream (Live)',
                color: const Color(0xFF6A1B9A),
                onTap: () => context.read<HomeController>().openCameraStream(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderHero extends StatelessWidget {
  const _PlaceholderHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.restaurant_menu_rounded, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          'Identifikasi Makanan\ndengan AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}
