# Banknot Tanıma

Görme engelli kullanıcılar için çevrimdışı Türk lirası banknot tanıma ve güvenlik özelliği rehberi.

Uygulama, kameradaki banknotun kupür değerini cihaz üzerinde çalışan bir TFLite modeliyle tanır ve sonucu Türkçe seslendirir. Ardından ilgili kupürün güvenlik özelliklerini adım adım anlatır.

- İnternet, Firebase veya veritabanı kullanmaz.
- Model ve güvenlik özelliği metinleri uygulama içinde saklanır.
- Banknotun gerçek veya sahte olduğuna karar vermez; yalnızca değer ve güvenlik özelliği rehberliği sunar.

## Çalıştırma

```bash
flutter pub get
flutter run
```

Kamera ve Türkçe metin okuma desteği için Android veya iOS cihaz kullanın.

## Yapı

- `lib/bloc`: Tarama olayları, durumları ve iş akışı
- `lib/repository`: Model çıkarımı ve güvenlik özelliği eşleştirmesi
- `lib/services`: TFLite, kamera ve metin okuma servisleri
- `lib/ui`: Erişilebilir tarama ekranı
- `assets`: TFLite modeli ve güvenlik özelliği metinleri
