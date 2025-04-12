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
- Pil tasarrufu modu ve performans optimizasyonları
- Animasyonlu kullanıcı arayüzü elemanları
- Tutarlı tema ve görsel dil

## 🏗️ Mimari Yapı

Uygulama MVVM (Model-View-ViewModel) mimarisi kullanılarak geliştirilmiştir:

### Model
- Veri yapıları ve iş mantığı
- CoreData ile veri kalıcılığı
- Sudoku algoritmaları ve çözüm stratejileri
- Hücre, değer ve tahta yönetimi

### View
- SwiftUI kullanıcı arayüz bileşenleri
- Tema ve görsel öğeler
- Animasyonlar ve geçişler
- Tutarlı görsel dil ve UI/UX

### ViewModel
- Model ve View arasındaki bağlantı
- Kullanıcı etkileşimlerini yönetme
- İş mantığını görsel bileşenlere dönüştürme
- State yönetimi ve değişim bildirimleri

## 📦 Kullanılan Framework'ler

### SwiftUI
- Modern, deklaratif UI geliştirme framework'ü
- Tüm kullanıcı arayüzü bileşenleri SwiftUI ile oluşturulmuştur
- View modifiers, layout sistemleri ve geçiş animasyonları için kullanılmıştır
- Responsive tasarım ve farklı ekran boyutları için uyarlamalar

### CoreData
- Yerel veritabanı ve veri kalıcılığı
- Kaydedilmiş oyunlar, yüksek skorlar ve kullanıcı ilerleme verileri
- Entity-ilişki modelleri ve NSManagedObject alt sınıfları
- NSPersistentContainer ve context yönetimi

### Combine
- Reaktif programlama için kullanılan framework
- Asenkron ve olay tabanlı programlama desteği
- Veri akışlarını yönetme ve işleme
- Publisher-Subscriber modeli ile component iletişimi

### Foundation
- Temel veri tipleri ve işlevler
- Date, Timer ve TimeInterval yönetimi
- String işlemleri ve formatlamalar
- UserDefaults ile kullanıcı ayarları yönetimi

## 📂 Proje Yapısı

### Ana Bileşenler
- **SudokuApp.swift**: Uygulamanın giriş noktası. Uygulama durumunu ve ortam ayarlarını yönetir. Persistence Controller'ı başlatır ve uygulamanın tema ayarlarını kontrol eder. Scene delegasyonu ve yaşam döngüsü yönetimi burada gerçekleşir.

- **ContentView.swift**: Ana sayfa yapısı ve navigasyon akışı. Oyun modu seçimi, ayarlar ve skor ekranları arasında geçişi sağlar. Ana oyun arayüzü burada oluşturulur ve SudokuViewModel ile bağlantı kurulur.

- **StartupView.swift**: Uygulama başlangıç ekranı. Uygulama açılışında gösterilen karşılama ve yükleme ekranı. Veri hazırlanma aşamasını yönetir.

### View Katmanı
#### Oyun Arayüzü
- **GameView.swift**: Oyun tahtasını ve kontrolleri içeren ana oyun arayüzü. Hücre seçimi, değer girişi, ipucu kullanımı gibi temel oyun etkileşimlerini yönetir.

- **SudokuBoardView.swift**: Sudoku tahtasının görsel temsilini sağlayan view. 9x9'luk ızgarayı ve hücrelerin düzenini yönetir.

- **SudokuCellView.swift**: Tek bir Sudoku hücresinin görünümünü ve davranışını tanımlar. Seçim durumları, vurgulama, çakışma göstergeleri ve kalem işaretleri gibi özellikleri içerir.

- **NumberPadView.swift**: Sayı girişi için kullanılan tuş takımı. Oyuncunun değer seçimini ve kalem modu geçişlerini yönetir.

- **PencilMarksView.swift**: Bir hücredeki not edilmiş olası değerleri görüntüler. Compact layout ve dinamik boyutlandırma sağlar.

- **GameCompletionView.swift**: Oyun tamamlandığında gösterilen sonuç ekranı. Skor, süre ve istatistikleri gösterir.

- **HintExplanationView.swift**: İpucu özelliği kullanıldığında gösterilen açıklama ekranı. Çözüm stratejisini görselleştirir.

#### Navigasyon ve Menüler
- **MainMenuView.swift**: Ana menü arayüzü ve navigasyon merkezi. Oyun modları, ayarlar ve diğer bölümlere erişim sağlar.

- **SavedGamesView.swift**: Kaydedilmiş oyun listesini görüntüler ve oyuna devam etme imkanı sunar. Filtreleme ve sıralama özellikleri içerir.

- **ScoreboardView.swift**: Yüksek skorları ve oyun istatistiklerini gösteren arayüz. Zorluk seviyelerine göre filtreleme yapılabilir.

- **SettingsView.swift**: Uygulama ayarlarını düzenleme arayüzü. Tema seçimi, ses ayarları, bildirim tercihleri gibi kullanıcı tercihlerini yönetir.

#### Kullanıcı Yönetimi ve Öğretici
- **LoginView.swift**: Kullanıcı giriş ekranı. Kimlik doğrulama ve profil erişimini sağlar.

- **RegisterView.swift**: Yeni kullanıcı kayıt ekranı. Hesap oluşturma işlemlerini yönetir.

- **TutorialView.swift**: Yeni başlayanlar için öğretici içerik. Sudoku kuralları ve uygulama kullanımını anlatır.

- **TutorialOverlayView.swift**: Oyun içi yardım ve ipuçları gösteren katman. Adım adım rehberlik sağlar.

#### UI Bileşenleri
- **AnimatedSudokuLogo.swift**: Özel animasyonlu Sudoku logosu. Uygulama kimliğini görsel olarak temsil eder.

### ViewModel Katmanı
- **SudokuViewModel.swift**: Oyun mantığını yöneten ana bileşen. Hücre seçimi, değer girişi, oyun durumu kontrolü, ipucu sistemi, zamanlayıcı yönetimi gibi kritik işlevleri içerir. Ayrıca kaydetme/yükleme işlemlerini ve skor hesaplamalarını koordine eder. (2300+ satır)

- **TimerViewModel.swift**: Oyun süresi takibi ve formatlaması için kullanılan bileşen. Duraklatma, devam etme ve sıfırlama gibi zamanlayıcı kontrollerini sağlar. (SudokuViewModel içinde implement edilmiş)

- **SettingsViewModel.swift**: Kullanıcı ayarlarının saklanması ve güncellenmesi işlemlerini yönetir. UserDefaults ile kalıcı ayarları işler. (SettingsView içinde implement edilmiş)

### Model Katmanı
- **SudokuBoard.swift**: Sudoku tahtasının temel veri yapısını ve mantığını içerir (2600+ satır):
  - Tahta oluşturma algoritmaları
  - Geçerlilik kontrolleri (satır, sütun, blok)
  - Çözüm üretme ve doğrulama
  - Zorluk seviyelerine göre ipucu ayarlama
  - Kalem işaretleri yönetimi
  - Çözüm stratejileri implementasyonu:
    - Naked Singles/Pairs/Triples
    - Hidden Singles/Pairs/Triples
    - Pointing Pairs/Triples
    - Box-Line Reduction
    - X-Wing ve Swordfish teknikleri

- **ScoreManager.swift**: Yüksek skorları kaydetme, yükleme ve sıralama işlemlerini yürütür. CoreData ile entegre çalışır.

- **PersistenceController.swift**: CoreData altyapısını yöneten bileşen. Veritabanı bağlantısı, modelleme ve veri kalıcılığını sağlar.

- **SudokuModel.xcdatamodeld**: Ana veri modeli. SavedGame ve HighScore entity'lerini tanımlar.

- **ScoreModel.xcdatamodeld**: Skor yönetimi için özel veri modeli.

### Yönetici Sınıflar (Managers)
- **SoundManager.swift**: Oyun seslerini yöneten sınıf. Ses efektlerinin yüklenmesi, oynatılması ve ses seviyesi kontrollerini sağlar.

- **PowerSavingManager.swift**: Pil durumu ve güç tasarrufu modu yönetimi. Düşük pil durumunda optimize edilmiş ayarlar sunar.

- **TutorialManager.swift**: Öğretici içerikleri ve yardım ipuçlarını yöneten sınıf. Adım adım rehberlik ve kullanıcı ilerlemesini takip eder.

### Extensions
- **ColorExtension.swift**: Renk teması ve özelleştirmeleri için renk uzantıları. Arayüzde kullanılan özel renkleri tanımlar.

- **ViewTransitionExtension.swift**: Görünüm geçişleri ve animasyonları için uzantılar. Ekran değişimlerini özelleştirir.

- **DateExtension.swift**: Tarih formatlaması ve skor ekranlarında kullanılan zaman gösterimi için uzantılar.

- **NSManagedObjectExtensions.swift**: CoreData entity'leri için yardımcı metotlar içeren uzantılar.

### CoreDataModels
- **SudokuModel.xcdatamodeld**: Uygulama veritabanı şemasını tanımlayan CoreData modeli. SavedGame ve HighScore entity'lerini içerir.
  
- **ScoreModel.xcdatamodeld**: Skorları saklamak için kullanılan ikincil CoreData modeli.

### Resources
- **Assets.xcassets**: Uygulama ikonları, renkler ve görseller
  - PrimaryBlue, PrimaryGreen, PrimaryOrange, PrimaryPurple, PrimaryRed renk setleri
  - SudokuBackground, SudokuCell gibi UI renkleri
  - Sistem ikonları ve özel grafikler

## 🛠️ Teknik Detaylar

### Mimari Yaklaşımlar
1. **ThemeManager**:
   - Singleton tasarım deseniyle uygulamanın temasını yönetir
   - Karanlık mod/açık mod geçişleri için kullanılır
   - Görsel temanın tüm uygulama genelinde tutarlı olmasını sağlar

2. **ColorManager**:
   - Renk paletlerini merkezi olarak yöneten yapı
   - Tema değişikliklerinde renk değişimleri için gerekli değerleri sağlar
   - Ana renkler (primaryBlue, primaryGreen vb.) ve yardımcı renkler (hata, uyarı, başarı)

3. **Environment Values**:
   - SwiftUI'nin çevresel değerleri taşıyan yapısı
   - Tema, metin boyutu gibi değerleri tüm uygulama içinde paylaşır
   - @Environment ve @EnvironmentObject ile değer aktarımı

4. **State Yönetimi**:
   - @State, @Binding, @Published, @ObservedObject kullanımı
   - Reaktif arayüz güncellemeleri ve veri akışı

### Tahta Oluşturma Algoritması
1. Temel bir 9x9 desen oluşturma
2. Değerleri, satırları ve sütunları karıştırarak benzersiz tahtalar üretme
3. Zorluk seviyesine göre belirli sayıda hücreyi kaldırma
4. Tahtanın çözülebilirliğini doğrulama
5. Zorluk seviyesine göre çözüm stratejileri kontrolü:
   - Kolay: Naked Singles oranı ≥ 1.2
   - Orta: Hidden Singles ve Naked Pairs gerektirir
   - Zor: Hidden Pairs ve Pointing Pairs gerektirir
   - Uzman: X-Wing ve ileri teknikler gerektirir

### Kalem İşaretleri (Pencil Marks)
- Oyuncuların bir hücreye yerleştirebilecekleri olası değerleri not etmelerini sağlar
- Her hücre için ayrı olası değerler seti tutulur
- Otomatik kalem işareti güncellemesi yapılabilir
- PencilMarksView ile kompakt ve okunabilir yerleşim

### Güç Tasarrufu Yönetimi
- PowerSavingManager sınıfı ile pil durumu takibi
- Düşük pil durumunda animasyonların ve arka plan işlemlerinin optimizasyonu
- Kullanıcıya pil tasarrufu modu hakkında bilgi ve seçenekler sunma

### Veri Yönetimi
- CoreData ile oyun durumu kaydedilir
- Yüksek skorlar yerel veritabanında saklanır
- Kullanıcı ayarları UserDefaults ile kalıcı hale getirilir
- NSPersistentContainer ve context yönetimi
- Background thread ve main thread senkronizasyonu

### UI/UX Tasarım Prensipleri
- Tutarlı gradient arka planlar ve renk paletleri
- Modern kartlar ve konteynerler için gölge ve kenar tasarımları
- Zorluk seviyelerine göre renk kodlaması
- Animasyonlu geçişler ve etkileşimler
- Erişilebilirlik için ayarlanabilir metin boyutları
- Karanlık/Aydınlık tema desteği

## 🚀 Planlanan İyileştirmeler

1. Daha akıcı sayfa geçişleri
2. Hücre seçimi ve değer girişi için hoş animasyonlar
3. Yeni başlayanlar için adım adım rehberlik
4. Arka plan işlemlerini optimize etme
5. Gelişmiş pil tasarrufu modu
6. Çevrimiçi liderlik tablosu ve kullanıcı profilleri
7. İstatistik grafikleri ve detaylı oyun analizi
8. Daha fazla dil desteği

## 🐛 Bilinen Sorunlar ve Çözümleri

- CoreData modelleri (SudokuModel ve ScoreModel) arasındaki tutarsızlıklar nedeniyle yaşanan çökmeler düzeltildi
- PersistenceController, SudokuModel'i kullanacak şekilde güncellendi
- ScoreManager sınıfı, Score entity'si yerine HighScore entity'sini kullanacak şekilde düzenlendi
- NSManagedObject extension'larında getName(), getUsername() ve getEmail() metodları genel extension'a eklendi
- Yüksek CPU kullanımına neden olan animasyon döngüleri optimize edildi
- Bellek sızıntılarına neden olan capture list sorunları çözüldü
