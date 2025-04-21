# Katkıda Bulunma Kılavuzu

## 🚀 Başlarken

Sudoku projemize katkıda bulunmak istediğiniz için teşekkür ederiz! Bu doküman, projeye katkıda bulunurken izlemeniz gereken adımları ve dikkat etmeniz gereken kuralları içermektedir.

## 🧩 Katkıda Bulunma Süreci

1. Projeyi forklayın
2. Geliştirme branşınızı oluşturun (`git checkout -b feature/YeniOzellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'YeniOzellik: Açıklama'`)
4. Branşınızı uzak sunucuya gönderin (`git push origin feature/YeniOzellik`)
5. Bir Pull Request oluşturun

## 📋 Kod Standartları

### Swift Stil Kılavuzu

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)'a uyun
- Değişken ve fonksiyon isimleri açıklayıcı olmalı
- SwiftLint kurallarına uyun
- Tekrarlayan kodu fonksiyonlara veya uzantılara taşıyın

### Kod Formatı

- İçe aktarma ifadelerini alfabetik sırayla düzenleyin
- Her dosya yeni bir satırla sonlanmalı
- Boşluk karakterleri yerine tab kullanmayın
- Satır sonundaki boşlukları kaldırın
- Kodunuzu yorum satırlarıyla açıklayın

## 🧪 Test Etme

- Yeni özellikleri farklı iOS sürümlerinde test edin
- Düşük performanslı cihazlarda test yapın
- Hem aydınlık hem karanlık temada testi gerçekleştirin
- Farklı dil ayarlarını test edin
- Erişilebilirlik testleri yapın (VoiceOver, vb.)

## 📝 Commit Mesajları

İyi bir commit mesajı şunları içermelidir:

- İlk satırda değişikliğin kısa bir özeti (50 karakter veya daha az)
- Gerekirse, bir boş satırdan sonra daha ayrıntılı açıklama
- Bağlantılı sorun numarasına referans (varsa)

Örnek:
```
Fix: Dil değiştirme sonrası UI güncelleme sorunu

Dil değiştirildiğinde bazı UI elementleri doğru şekilde güncellenemiyordu.
Bu sorunu DispatchQueue.main.async bloğu içinde UI güncellemelerini yaparak çözdük.

Closes #123
```

## 🎯 Sorun ve Özellik İstekleri

- Yeni özellik önerilerini veya sorunları bildirmeden önce, benzer bir özellik veya sorun olup olmadığını kontrol edin
- Sorun bildirirken net ve tekrarlanabilir adımlar sağlayın
- Uygulama sürümü, iOS sürümü ve cihaz bilgilerini ekleyin
- Gerektiğinde ekran görüntüleri ekleyin
- Öneri yaparken, önerilen özelliğin neden kullanıcılar için faydalı olacağını açıklayın

## 🌐 Lokalizasyon

- Yeni dil ekliyorsanız, tüm dize kaynaklarının çevirisini tamamlamaya özen gösterin
- Mevcut çevirileri düzeltirken, doğal dil kullanıcılarından doğrulama alın
- Yer tutucuları (%@, %d, vb.) koruduğunuzdan emin olun

## 🔒 Güvenlik

- Kullanıcı verilerini güvenli şekilde yönetin
- Üçüncü taraf kütüphaneleri eklerken lisans uyumluluğunu kontrol edin
- API anahtarları veya gizli bilgileri asla commit etmeyin

## 📱 Performans

- Yeni özellekler eklerken performans etkisini göz önünde bulundurun
- Bellek sızıntılarını önleyin (özellikle closure ve döngüsel referanslarda)
- Özellikle arka plan/önplan geçişlerinde uygulama durumunu doğru şekilde yönetin

## 📚 Dokümantasyon

- Karmaşık veya yeni işlevler için kod içi yorumlar ekleyin
- Gerektiğinde README.md dosyasını güncelleyin
- Yeni bir özellik ekliyorsanız, kullanıcı kılavuzunu da güncelleyin

## 🎉 Teşekkürler!

Katkınız, Sudoku uygulamasını herkes için daha iyi hale getirmemize yardımcı oluyor. Katılımınız için teşekkür ederiz!

---

Bu kılavuz hakkında sorularınız varsa, lütfen bir sorun (issue) açın veya lil.necati@gmail.com adresine e-posta gönderin. 