# Sudoku Uygulaması

Bu uygulama, SwiftUI kullanılarak iOS platformu için geliştirilmiş kapsamlı bir Sudoku oyunudur. Bu doküman, uygulamanın yapısını, bileşenlerini ve özelliklerini detaylı olarak anlatmaktadır.

## 📱 Uygulama Özellikleri

- Dört farklı zorluk seviyesi (Kolay, Orta, Zor, Uzman)
- Kalem işaretleri ile olası değerleri not etme
- Oyun durumunu kaydetme ve yükleme
- Skor takibi ve liderlik tablosu
- Karanlık/aydınlık tema desteği
- Hücre vurgulama ve çakışma tespiti
- Oyun istatistikleri ve hata sayısını takip etme
- Kolay: sadece direkt eleme
- Orta: naked pairs/triples
- Zor: hidden pairs/triples
- Uzman: X-Wing, Swordfish gibi teknikler


## 🏗️ Mimari Yapı

Uygulama MVVM (Model-View-ViewModel) mimarisi kullanılarak geliştirilmiştir:

### Model
- Veri yapıları ve iş mantığı
- CoreData ile veri kalıcılığı

### View
- SwiftUI kullanıcı arayüz bileşenleri
- Tema ve görsel öğeler

### ViewModel
- Model ve View arasındaki bağlantı
- Kullanıcı etkileşimlerini yönetme

## 📂 Proje Yapısı

### App
- **SudokuApp.swift**: Uygulamanın giriş noktası. Uygulama durumunu ve ortam ayarlarını yönetir. Persistence Controller'ı başlatır ve uygulamanın tema ayarlarını kontrol eder.

### Views
- **ContentView.swift**: Ana sayfa yapısı ve navigasyon akışı. Oyun modu seçimi, ayarlar ve skor ekranları arasında geçişi sağlar. Ana oyun arayüzü burada oluşturulur ve SudokuViewModel ile bağlantı kurulur.
  
- **GameView.swift**: Oyun tahtasını ve kontrolleri içeren ana oyun arayüzü. Hücre seçimi, değer girişi, ipucu kullanımı gibi temel oyun etkileşimlerini yönetir.
  
- **CellView.swift**: Tek bir Sudoku hücresinin görünümünü ve davranışını tanımlar. Seçim durumları, vurgulama, çakışma göstergeleri ve kalem işaretleri gibi özellikleri içerir.
  
- **SettingsView.swift**: Uygulama ayarlarını düzenleme arayüzü. Tema seçimi, ses ayarları, bildirim tercihleri gibi kullanıcı tercihlerini yönetir.
  
- **ScoreView.swift**: Yüksek skorları ve oyun istatistiklerini gösteren arayüz. Zorluk seviyelerine göre filtreleme yapılabilir.

### ViewModels
- **SudokuViewModel.swift**: Oyun mantığını yöneten ana bileşen. Hücre seçimi, değer girişi, oyun durumu kontrolü, ipucu sistemi, zamanlayıcı yönetimi gibi kritik işlevleri içerir. Ayrıca kaydetme/yükleme işlemlerini ve skor hesaplamalarını koordine eder.
  
- **TimerViewModel.swift**: Oyun süresi takibi ve formatlaması için kullanılan bileşen. Duraklatma, devam etme ve sıfırlama gibi zamanlayıcı kontrollerini sağlar.
  
- **SettingsViewModel.swift**: Kullanıcı ayarlarının saklanması ve güncellenmesi işlemlerini yönetir. UserDefaults ile kalıcı ayarları işler.

### Models
- **SudokuBoard.swift**: Sudoku tahtasının temel veri yapısını ve mantığını içerir:
  - Tahta oluşturma algoritmaları
  - Geçerlilik kontrolleri (satır, sütun, blok)
  - Çözüm üretme ve doğrulama
  - Zorluk seviyelerine göre ipucu ayarlama
  - Kalem işaretleri yönetimi
  
- **ScoreManager.swift**: Yüksek skorları kaydetme, yükleme ve sıralama işlemlerini yürütür. CoreData ile entegre çalışır.
  
- **PersistenceController.swift**: CoreData altyapısını yöneten bileşen. Veritabanı bağlantısı, modelleme ve veri kalıcılığını sağlar.
  
- **Difficulty.swift**: Zorluk seviyelerini tanımlayan enum yapısı. Her seviye için ipucu sayısı aralıkları ve skor çarpanları burada belirlenir.

### Extensions
- **ColorExtension.swift**: Renk teması ve özelleştirmeleri için renk uzantıları. Arayüzde kullanılan özel renkleri tanımlar.
  
- **DateExtension.swift**: Tarih formatlaması ve skor ekranlarında kullanılan zaman gösterimi için uzantılar.
  
- **NSManagedObjectExtensions.swift**: CoreData entity'leri için yardımcı metotlar içeren uzantılar.

### CoreDataModels
- **SudokuModel.xcdatamodeld**: Uygulama veritabanı şemasını tanımlayan CoreData modeli. SavedGame ve HighScore entity'lerini içerir.
  
- **ScoreModel.xcdatamodeld**: Skorları saklamak için kullanılan ikincil CoreData modeli.

## 🛠️ Teknik Detaylar

### Tahta Oluşturma Algoritması
1. Temel bir 9x9 desen oluşturma
2. Değerleri, satırları ve sütunları karıştırarak benzersiz tahtalar üretme
3. Zorluk seviyesine göre belirli sayıda hücreyi kaldırma
4. Tahtanın çözülebilirliğini doğrulama

### Kalem İşaretleri (Pencil Marks)
- Oyuncuların bir hücreye yerleştirebilecekleri olası değerleri not etmelerini sağlar
- Her hücre için ayrı olası değerler seti tutulur
- Otomatik kalem işareti güncellemesi yapılabilir

### Veri Yönetimi
- CoreData ile oyun durumu kaydedilir
- Yüksek skorlar yerel veritabanında saklanır
- Kullanıcı ayarları UserDefaults ile kalıcı hale getirilir

## 🚀 Planlanan İyileştirmeler

1. Daha akıcı sayfa geçişleri
2. Hücre seçimi ve değer girişi için hoş animasyonlar
3. Yeni başlayanlar için adım adım rehberlik
4. Arka plan işlemlerini optimize etme
5. Güç tasarrufu modu

## 🐛 Bilinen Sorunlar ve Çözümleri

- CoreData modelleri (SudokuModel ve ScoreModel) arasındaki tutarsızlıklar nedeniyle yaşanan çökmeler düzeltildi
- PersistenceController, SudokuModel'i kullanacak şekilde güncellendi
- ScoreManager sınıfı, Score entity'si yerine HighScore entity'sini kullanacak şekilde düzenlendi
- NSManagedObject extension'larında getName(), getUsername() ve getEmail() metodları genel extension'a eklendi
