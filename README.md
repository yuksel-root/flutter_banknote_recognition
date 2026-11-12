# Banknot Tanıma

Çevrimdışı Türk lirası banknot tanıma uygulaması.

Uygulama, kameradaki banknotun kupür değerini cihaz üzerinde çalışan bir TFLite modeliyle tanır. Canlı analiz sırasında en olası beş kupürü yüzdeleriyle gösterir ve kararlı sonuç oluştuğunda yalnızca banknot değerini Türkçe seslendirir.

## Özellikler

- 5, 10, 20, 50, 100 ve 200 TL kupürlerini tanır.
- Tamamen çevrimdışı çalışır; internet, Firebase veya veritabanı kullanmaz.
- Kameradan gelen tam kareyi saniyede 5 kez analiz eder.
- En olası beş kupürü ve yüzdelerini gerçek zamanlı gösterir.
- Her kare için analiz süresini gösterir.
- Aynı kupür üç kare üst üste güven eşiğini geçtiğinde sonucu kabul eder.
- Sonucu yalnızca kupür değeri olarak Türkçe seslendirir.
- Tanıma çerçevesi kullanmaz; banknotun tamamı kamerada görünmelidir.
- Yüksek kontrastlı koyu arayüz, büyük düğmeler ve ekran okuyucu etiketleri sunar.
- Banknotun gerçek veya sahte olduğuna karar vermez.

## Kullanım

1. Uygulamayı açın ve kameranın hazır olmasını bekleyin.
2. Banknotu kameraya, tüm yüzeyi görünecek şekilde tutun.
3. Canlı analizde ilk beş tahmin ve yüzdeleri güncellenir.
4. Aynı kupür üç kare boyunca kararlı kalırsa uygulama değeri sesli olarak söyler.
5. Sonuç ekranında tanınan değer ve güven oranı gösterilir.
6. `Yeniden Tara` ile analizi tekrar başlatabilirsiniz.

## Model ve tanıma

- Model dosyası: `assets/model.tflite`
- Giriş: 224 x 224 x 3 RGB görüntü
- Sınıflar: `5 TL`, `10 TL`, `20 TL`, `50 TL`, `100 TL`, `200 TL`
- Kamera kareleri cihaz yönüne göre döndürülür, YUV420 veya BGRA biçiminden RGB'ye çevrilir ve modele yeniden boyutlandırılarak verilir.
- Tanıma çerçevesi veya kırpma yoktur; model tam kamera karesini değerlendirir.
- Her karede en yüksek olasılıklı beş sınıf sıralanır ve yüzdeleri arayüzde gösterilir.
- Aynı sınıf üç ardışık karede güven eşiğini geçmelidir. Etiket değişirse veya güven eşiğin altına düşerse kare sayacı sıfırlanır.
- Varsayılan güven eşiği `0.7` değerindedir. Eşik değeri `SharedPreferences` içindeki `confidence_threshold` anahtarından okunur.
- Eşiğin altındaki kareler kararlı sonuç için sayılmaz; uygulama analize devam eder.
- Kupür bazlı güvenlik özelliği metinleri `assets/security_features.json` dosyasında tutulur; canlı tanıma ekranında gösterilmez veya seslendirilmez.

## Geliştirme durumu

- Kamera önizlemesi, canlı görüntü akışı ve kamera hata yönetimi tamamlandı.
- Gerçek TFLite modeliyle cihaz üzeri çıkarım tamamlandı.
- Tam kare analizi, saniyede 5 kare sabitlemesi ve gerçek zamanlı ilk beş tahmin tamamlandı.
- Üç kareli kararlı tanıma ve güven eşiği tamamlandı.
- Yalnızca kupür değerini söyleyen Türkçe seslendirme tamamlandı.
- Durum yönetimi `flutter_bloc` ile, nesne yaşam döngüsü `StatefulWidget` kullanmadan uygulandı.
- `flutter analyze` ve `flutter test` temiz geçmektedir.
- Hata ayıklama ve sürüm APK derlemeleri başarıyla üretilmektedir.

## Gereksinimler

- Flutter 3.41 veya üzeri
- Dart 3.11 veya üzeri
- Kamera ve Türkçe metin okuma desteği olan Android veya iOS cihaz

Android için kamera izni ve isteğe bağlı kamera özelliği `AndroidManifest.xml` içinde tanımlıdır. iOS için kamera kullanım açıklaması `Info.plist` içinde bulunur.

## Kurulum

```bash
flutter pub get
flutter run
```

Kamera ve seslendirme davranışını doğrulamak için fiziksel bir cihaz kullanın.

Hata ayıklama APK'sı üretmek için:

```bash
flutter build apk --debug
```

## Mimari

```text
lib/
  main.dart                         Uygulama başlangıcı ve bağımlılıklar
  app.dart                          MaterialApp ve tema
  bloc/
    scanner_event.dart              Tarama olayları
    scanner_state.dart              Tarama durumları
    scanner_bloc.dart               Canlı tarama iş akışı
    stable_frame_tracker.dart       Üç kareli kararlılık takibi
  repository/
    banknote_repository.dart        Model sonucu, eşik ve güvenlik rehberi
  services/
    camera_service.dart             Kamera yaşam döngüsü ve 5 FPS görüntü akışı
    tflite_service.dart             Kare dönüştürme ve model çıkarımı
    tts_service.dart                Türkçe metin okuma
  models/
    banknote_result.dart            Tanıma sonucu
    video_frame.dart                Kamera karesi ve düzlemleri
  ui/
    scanner_screen.dart             Erişilebilir tarama ekranı
    widgets/camera_preview.dart     Kamera önizlemesi
```

Tarama akışı:

```text
Kamera görüntü akışı
  -> CameraService (saniyede 5 kare)
  -> VideoFrame
  -> ScannerBloc
  -> BanknoteRepository
  -> TfliteService (tam kare, ilk beş tahmin)
  -> StableFrameTracker (üç kare, güven eşiği)
  -> ScannerResult veya ScannerError
  -> Ekran ve yalnızca kupür değerinin Türkçe seslendirilmesi
```

## Testler

```bash
flutter analyze
flutter test
```

Testler; model çıktısı normalizasyonu, ilk beş tahmin sıralaması, YUV420/BGRA dönüşümü, kare döndürme, kararlı kare takibi, güven eşiği, güvenlik özelliği eşleştirmesi, durum yönetimi ve temel arayüz davranışlarını kapsar.

## Gizlilik ve sınırlar

- Görüntüler cihaz dışına gönderilmez.
- İnternet bağlantısı gerekmez.
- Banknotun gerçek veya sahte olduğu tespit edilmez.
- Düşük ışık, bulanıklık veya banknotun kamerada yeterince büyük görünmemesi tanıma başarısını etkileyebilir.
- Uygulama bir değer tanıma aracıdır; resmi bir doğrulama aracı değildir.
