# Banknot Tanıma

Çevrimdışı Türk lirası banknot tanıma ve güvenlik özelliği rehberi.

Uygulama, kameradaki banknotun kupür değerini cihaz üzerinde çalışan bir TFLite modeliyle tanır ve sonucu Türkçe seslendirir. Ardından ilgili kupürün güvenlik özelliklerini adım adım anlatır.

## Özellikler

- 5, 10, 20, 50, 100 ve 200 TL kupürlerini tanır.
- Tamamen çevrimdışı çalışır; internet, Firebase veya veritabanı kullanmaz.
- Kameradan alınan görüntüyü cihaz üzerinde işler ve sonucu Türkçe seslendirir.
- Banknotu kameradaki çerçeveye göre kırparak arka planın sonucu etkilemesini azaltır.
- Üç kare yakalar ve en az iki karenin aynı sonucu vermesini bekleyerek kararlı tanıma yapar.
- Tanınan değerle birlikte güven oranını ve ilgili kupürün güvenlik özelliklerini okur.
- Yüksek kontrastlı koyu arayüz, büyük düğmeler ve ekran okuyucu etiketleri sunar.
- Banknotun gerçek veya sahte olduğuna karar vermez; yalnızca değer ve güvenlik özelliği rehberliği sunar.

## Kullanım

1. Uygulamayı açın ve kameranın hazır olmasını bekleyin.
2. Banknotu kameranın önündeki çerçeveye yerleştirin.
3. `Tara` düğmesine dokunun. Uygulama üç kare yakalar.
4. Uygulama değeri, güven oranını ve güvenlik özelliklerini sesli olarak bildirir.
5. Sonuç kararlı değilse uygulama banknotu sabit tutup tekrar denemenizi ister.
6. Gerektiğinde `Taramayı İptal Et` ile işlemi durdurabilirsiniz.

## Model ve güvenlik rehberi

- Model dosyası: `assets/model.tflite`
- Giriş: 224 x 224 x 3 RGB görüntü
- Sınıflar: `5 TL`, `10 TL`, `20 TL`, `50 TL`, `100 TL`, `200 TL`
- Görüntü, model girişine verilmeden önce EXIF yönüne göre düzeltilir.
- Kırpma, görüntü genişliğinin %95'i genişliğinde ve 2:1 oranında, dikeyde %45 merkezli bir bölgeyi alır; bu bölge model giriş boyutuna yeniden boyutlandırılır.
- Her kare için hem tam görüntü hem de çerçeve kırpması ayrı ayrı değerlendirilir. İki sonuç aynı kupürü vermezse kare geçersiz sayılır.
- Üç kare içinden en az iki kare aynı kupürde birleşmelidir; aksi halde uygulama sonucu reddeder.
- Güven eşiği, kare birleştirmesinden sonra kalan sonuca uygulanır.
- Model, 180 görüntülük bağımsız test kümesinde %96,1 doğruluk göstermiştir. `0.7` güven eşiğinde kabul edilen sonuçların %99,4'ü doğrudur.
- Varsayılan güven eşiği `0.7` değerindedir. Eşik değeri `SharedPreferences` içindeki `confidence_threshold` anahtarından okunur.
- Eşiğin altındaki sonuçlar kullanıcıya gösterilmez; uygulama banknotu tekrar denemesi için yönlendirme yapar.
- Güvenlik özelliği metinleri `assets/security_features.json` dosyasında kupür değerine göre saklanır.

## Geliştirme durumu

- Kamera önizlemesi, fotoğraf yakalama ve kamera hata yönetimi tamamlandı.
- Gerçek TFLite modeliyle cihaz üzeri çıkarım tamamlandı.
- Çerçeve kırpması, tam kare ile kırpma uzlaşması ve üç kareli kararlı tanıma tamamlandı.
- Güven eşiği, sonuç eşleştirme ve güvenlik özelliği yükleme tamamlandı.
- Türkçe metin okuma ve erişilebilir arayüz tamamlandı.
- Durum yönetimi `flutter_bloc` ile, nesne yaşam döngüsü `StatefulWidget` kullanmadan uygulandı.
- `flutter analyze` ve `flutter test` temiz geçmektedir.
- Hata ayıklama APK derlemesi başarıyla üretilmektedir.

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
    scanner_bloc.dart               Tarama iş akışı
  repository/
    banknote_repository.dart        Model sonucu, eşik ve güvenlik rehberi
  services/
    camera_service.dart             Kamera yaşam döngüsü ve fotoğraf yakalama
    tflite_service.dart             Görüntü hazırlama ve model çıkarımı
    tts_service.dart                Türkçe metin okuma
  models/
    banknote_result.dart            Tanıma sonucu
  ui/
    scanner_screen.dart             Erişilebilir tarama ekranı
    widgets/camera_preview.dart     Kamera önizlemesi ve yönlendirme çerçevesi
```

Tarama akışı:

```text
Kamera görüntüsü
  -> Üç kare yakalama
  -> ScanRequested
  -> ScannerProcessing
  -> BanknoteRepository
  -> TfliteService (tam kare + çerçeve kırpması)
  -> Kare çoğunluğu ve güven eşiği
  -> ScannerResult veya ScannerError
  -> Ekran ve Türkçe sesli geri bildirim
```

## Testler

```bash
flutter analyze
flutter test
```

Testler; görüntü hazırlama, çerçeve kırpması, tam kare ile kırpma uzlaşması, model çıktısı normalizasyonu, güven eşiği, kare çoğunluğu, güvenlik özelliği eşleştirmesi, durum yönetimi ve temel arayüz davranışlarını kapsar.

## Gizlilik ve sınırlar

- Görüntüler cihaz dışına gönderilmez.
- İnternet bağlantısı gerekmez.
- Banknotun gerçek veya sahte olduğu tespit edilmez.
- Düşük ışık, bulanıklık veya banknotun çerçeveye tam yerleşmemesi tanıma başarısını etkileyebilir.
- Uygulama bir güvenlik özelliği rehberidir; resmi bir doğrulama aracı değildir.
