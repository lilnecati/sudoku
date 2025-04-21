# 🧩 Sudoku Uygulaması

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.5-orange?style=for-the-badge&logo=swift" alt="Swift 5.5"/>
  <img src="https://img.shields.io/badge/iOS-15.0+-blue?style=for-the-badge&logo=apple" alt="iOS 15.0+"/>
  <img src="https://img.shields.io/badge/SwiftUI-3.0-red?style=for-the-badge&logo=swift" alt="SwiftUI 3.0"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
</p>

<p align="center">SwiftUI ile geliştirilmiş modern, özelleştirilebilir ve çok dilli Sudoku deneyimi.</p>

<div align="center">
  <img src="Assets/app_screenshot.png" width="800" alt="Sudoku Screenshots"/>
</div>

## 🌟 Özellikler

### Oyun Deneyimi
- **Dört zorluk seviyesi** - Kolay, Orta, Zor ve Uzman
- **Gelişmiş ipucu sistemi** - Stratejileri öğrenerek ilerleyin
- **Otomatik not sistemi** - Olası değerleri takip edin
- **Etkileşimli öğretici** - Oyunu adım adım öğrenin
- **Çoklu dil desteği** - Türkçe, İngilizce ve Fransızca

### Kullanıcı Arayüzü
- **Karanlık/Aydınlık tema** - Otomatik veya manuel seçim
- **Özelleştirilebilir metin boyutu** - Erişilebilirlik için
- **Animasyonlu geçişler** - Akıcı kullanıcı deneyimi
- **Duyarlı tasarım** - Tüm iOS cihazlarına uyum
- **Haptik geri bildirim** - Dokunsal deneyim

### Teknik Özellikler
- **Güç tasarrufu modu** - Pil ömrünü uzatın
- **Yüksek performans modu** - Akıcı animasyonlar
- **Otomatik ilerleme kaydı** - Oyunlarınız asla kaybolmaz
- **Yerel veri saklama** - İstatistikler ve skorlar
- **SwiftUI ile geliştirilmiş** - Modern kod tabanı

## 🚀 Başlarken

### Gereksinimler
- iOS 15.0 veya üzeri
- Xcode 13.0 veya üzeri
- Swift 5.5 veya üzeri

### Kurulum

```bash
# Projeyi klonlayın
git clone https://github.com/username/Sudoku.git

# Proje dizinine gidin
cd Sudoku

# Xcode projesi açın
open Sudoku.xcodeproj
```

## 🏗️ Mimari

Bu uygulama, MVVM (Model-View-ViewModel) mimari deseni kullanılarak tasarlanmıştır, aşağıdaki bileşenlerden oluşur:

### 📱 Görünüm Katmanı (View)
Kullanıcı arayüzünü oluşturan SwiftUI bileşenlerini içerir:
- `GameView.swift` - Ana oyun ekranı
- `SudokuBoardView.swift` - Sudoku tahtası
- `SettingsView.swift` - Uygulama ayarları
- `ScoreboardView.swift` - Skorlar ve istatistikler

### 🧠 ViewModel Katmanı
Görünüm ve model arasındaki bağlantıyı sağlar:
- `SudokuViewModel.swift` - Oyun mantığı ve veri yönetimi
- `TimerViewModel.swift` - Süre takibi
- `SettingsViewModel.swift` - Kullanıcı tercihleri

### 💾 Model Katmanı
Veri yapılarını ve iş mantığını içerir:
- `SudokuBoard.swift` - Tahta oluşturma ve çözüm algoritmaları
- `ScoreManager.swift` - Skor yönetimi
- `PersistenceController.swift` - CoreData entegrasyonu

### 🔧 Yönetici Sınıflar
Uygulama genelinde kullanılan hizmetleri sağlar:
- `LocalizationManager.swift` - Çoklu dil desteği
- `PowerSavingManager.swift` - Pil optimizasyonu
- `ThemeManager.swift` - Tema yönetimi
- `SoundManager.swift` - Ses efektleri

## 📋 Özellik Listesi

<details>
<summary><b>Zorluk Seviyeleri</b></summary>

- **Kolay**: Başlangıç seviyesi, temel stratejiler
- **Orta**: Orta zorlukta, naked pairs/triples
- **Zor**: İleri düzey, hidden pairs/triples
- **Uzman**: X-Wing, Swordfish gibi kompleks stratejiler
</details>

<details>
<summary><b>Not Sistemi</b></summary>

- Manuel not alma
- Otomatik not güncelleme
- Hücre içinde kompakt gösterim
- Çakışma vurgulama
</details>

<details>
<summary><b>Çoklu Dil Desteği</b></summary>

- Türkçe (Varsayılan)
- İngilizce
- Fransızca
- *Yakında:* İspanyolca, İtalyanca
</details>

<details>
<summary><b>Performans Özellikleri</b></summary>

- Güç tasarrufu modu
- Pil durumu takibi
- Yüksek performans modu
- Otomatik optimizasyonlar
</details>

## 🗺️ Yol Haritası

### Güncel Sürüm (1.0)
- ✅ Temel oyun mantığı ve kullanıcı arayüzü
- ✅ Dört zorluk seviyesi (Kolay, Orta, Zor, Uzman)
- ✅ Türkçe, İngilizce ve Fransızca dil desteği
- ✅ Kalem işaretleri ve ipucu sistemi
- ✅ Karanlık/Aydınlık tema desteği

### Yaklaşan Güncellemeler
- 🔲 İtalyanca ve İspanyolca dil desteği (v1.1)
- 🔲 Çevrimiçi liderlik tablosu (v1.2)
- 🔲 Günlük meydan okuma modu (v1.3)
- 🔲 Bulut senkronizasyonu (v1.4)
- 🔲 Widget desteği (v1.5)

## 🔧 Sorun Giderme

<details>
<summary><b>Bilinen Sorunlar ve Çözümleri</b></summary>

- **Dil değişikliği sonrası bazı metinler güncellenmeyebilir**: Uygulamayı yeniden başlatın
- **Düşük pil durumunda performans düşüşü**: Güç tasarrufu modunu etkinleştirin
- **Animasyonlarda gecikme**: Ayarlar'dan yüksek performans modunu açın
- **Kayıtlı oyun yüklenirken hata**: Son güncellemeyi yükleyin
</details>

## 👨‍💻 Katkıda Bulunma

Katkılarınızı memnuniyetle karşılıyoruz! Katkıda bulunmak için:

1. Bu repo'yu forklayın
2. Feature branch'inizi oluşturun (`git checkout -b feature/AmazingFeature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Branch'inize push edin (`git push origin feature/AmazingFeature`)
5. Pull Request açın

Katılımdan önce lütfen [katkıda bulunma kılavuzumuzu](CONTRIBUTING.md) okuyun.

## 📱 Ekran Görüntüleri

<div align="center">
  <img src="Assets/screenshot1.png" width="200" alt="Ana Menü"/>
  <img src="Assets/screenshot2.png" width="200" alt="Oyun Ekranı"/>
  <img src="Assets/screenshot3.png" width="200" alt="İpucu Sistemi"/>
  <img src="Assets/screenshot4.png" width="200" alt="Ayarlar"/>
</div>

## 📝 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır - detaylar için [LICENSE.md](LICENSE.md) dosyasına bakın.

## 🙏 Teşekkürler

- SwiftUI ve Combine dokümantasyonu için Apple'a
- Sudoku algoritmaları için açık kaynak topluluğuna
- Sürekli geri bildirim sağlayan test kullanıcılarımıza
- Lokalizasyon desteği için dil uzmanlarımıza

---

<p align="center">
  <sub>Geliştirici: Necati Yıldırım © 2024</sub>
</p>
