# Food Recognizer App

Aplikasi Flutter untuk mengidentifikasi makanan menggunakan Machine Learning.

## Fitur

- **Image Picker**: Pilih gambar dari galeri atau kamera
- **Image Cropper**: Crop gambar sebelum dianalisis  
- **Camera Stream**: Live scan makanan dengan kamera real-time
- **ML Inference (LiteRT/TFLite)**: Klasifikasi makanan menggunakan model AIY Food Classifier v1 (2024 kelas makanan)
- **Background Isolate**: Inferensi dijalankan di thread terpisah agar UI tetap responsif
- **MealDB API**: Resep lengkap termasuk bahan dan cara membuat
- **Gemini API**: Informasi nutrisi (kalori, karbohidrat, lemak, serat, protein)

## Setup

### 1. Gemini API Key

Jalankan aplikasi dengan dart-define (API Key tidak di-hardcode):

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_API_KEY_HERE
```

### 2. Build

```bash
flutter pub get
flutter run
```

## Struktur Proyek

```
lib/
├── controller/
│   ├── home_controller.dart     # Image pick, crop, navigasi
│   └── result_controller.dart   # Orchestrasi ML + API calls
├── service/
│   ├── food_classifier_service.dart  # TFLite inference (Isolate)
│   ├── meal_db_service.dart          # TheMealDB API
│   └── gemini_nutrition_service.dart # Gemini API
├── ui/
│   ├── home_page.dart           # Halaman utama
│   ├── result_page.dart         # Halaman hasil prediksi
│   └── camera_stream_page.dart  # Live camera stream
├── widget/
│   └── classification_item.dart
└── main.dart
assets/
├── 1.tflite                    # Model AIY Food Classifier
├── probability-labels-en.txt   # Label bahasa Inggris
└── probability-labels.txt      # Label kode KG
```
