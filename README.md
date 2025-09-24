# 🧩 Sudoku Uygulaması

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.5-orange?style=for-the-badge&logo=swift" alt="Swift 5.5"/>
  <img src="https://img.shields.io/badge/iOS-15.0+-blue?style=for-the-badge&logo=apple" alt="iOS 15.0+"/>
  <img src="https://img.shields.io/badge/SwiftUI-3.0-red?style=for-the-badge&logo=swift" alt="SwiftUI 3.0"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
</p>

<p align="center">Bu uygulama, SwiftUI kullanılarak iOS platformu için geliştirilmiş kapsamlı bir Sudoku oyunudur. Bu doküman, uygulamanın yapısını, bileşenlerini ve özelliklerini detaylı olarak anlatmaktadır.</p>

<div align="center">
  <img src="screenshots/anasayfa.png" width="800" alt="Sudoku Screenshots"/>
</div>

## 📱 Uygulama Özellikleri

<details open>
<summary><b>Oyun Özellikleri</b></summary>

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
- **Yeni:** Çoklu dil desteği (İngilizce, Türkçe, Fransızca)
- **Yeni:** Gelişmiş öğretici ve rehberlik sistemi
- **Yeni:** Performans optimizasyonları ve hızlandırılmış tahta oluşturma
</details>

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

## 🏗️ Mimari Yapı

Uygulama MVVM (Model-View-ViewModel) mimarisi kullanılarak geliştirilmiştir:

<details>
<summary><b>Model Katmanı</b></summary>

- Veri yapıları ve iş mantığı
- CoreData ile veri kalıcılığı
- Sudoku algoritmaları ve çözüm stratejileri
- Hücre, değer ve tahta yönetimi
</details>

<details>
<summary><b>View Katmanı</b></summary>

- SwiftUI kullanıcı arayüz bileşenleri
- Tema ve görsel öğeler
- Animasyonlar ve geçişler
- Tutarlı görsel dil ve UI/UX
</details>

<details>
<summary><b>ViewModel Katmanı</b></summary>

- Model ve View arasındaki bağlantı
- Kullanıcı etkileşimlerini yönetme
- İş mantığını görsel bileşenlere dönüştürme
- State yönetimi ve değişim bildirimleri
</details>

## 📦 Kullanılan Framework'ler

<details>
<summary><b>SwiftUI</b></summary>

- Modern, deklaratif UI geliştirme framework'ü
- Tüm kullanıcı arayüzü bileşenleri SwiftUI ile oluşturulmuştur
- View modifiers, layout sistemleri ve geçiş animasyonları için kullanılmıştır
- Responsive tasarım ve farklı ekran boyutları için uyarlamalar
</details>

<details>
<summary><b>CoreData</b></summary>

- Yerel veritabanı ve veri kalıcılığı
- Kaydedilmiş oyunlar, yüksek skorlar ve kullanıcı ilerleme verileri
- Entity-ilişki modelleri ve NSManagedObject alt sınıfları
- NSPersistentContainer ve context yönetimi
</details>

<details>
<summary><b>Combine</b></summary>

- Reaktif programlama için kullanılan framework
- Asenkron ve olay tabanlı programlama desteği
- Veri akışlarını yönetme ve işleme
- Publisher-Subscriber modeli ile component iletişimi
</details>

<details>
<summary><b>Foundation</b></summary>

- Temel veri tipleri ve işlevler
- Date, Timer ve TimeInterval yönetimi
- String işlemleri ve formatlamalar
- UserDefaults ile kullanıcı ayarları yönetimi
</details>

## 📂 Proje Yapısı

<details>
<summary><b>Ana Bileşenler</b></summary>

- **SudokuApp.swift**: Uygulamanın giriş noktası. Uygulama durumunu ve ortam ayarlarını yönetir. Persistence Controller'ı başlatır ve uygulamanın tema ayarlarını kontrol eder. Scene delegasyonu ve yaşam döngüsü yönetimi burada gerçekleşir.

- **ContentView.swift**: Ana sayfa yapısı ve navigasyon akışı. Oyun modu seçimi, ayarlar ve skor ekranları arasında geçişi sağlar. Ana oyun arayüzü burada oluşturulur ve SudokuViewModel ile bağlantı kurulur.

- **StartupView.swift**: Uygulama başlangıç ekranı. Uygulama açılışında gösterilen karşılama ve yükleme ekranı. Veri hazırlanma aşamasını yönetir.
</details>

<details>
<summary><b>View Katmanı</b></summary>

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

- **ScoreboardView.swift**: Yüksek skorları ve oyun istatistiklerini gösteren arayüz. Zorluk seviyeselerine göre filtreleme yapılabilir.

- **SettingsView.swift**: Uygulama ayarlarını düzenleme arayüzü. Tema seçimi, ses ayarları, bildirim tercihleri gibi kullanıcı tercihlerini yönetir.

#### Kullanıcı Yönetimi ve Öğretici
- **LoginView.swift**: Kullanıcı giriş ekranı. Kimlik doğrulama ve profil erişimini sağlar.

- **RegisterView.swift**: Yeni kullanıcı kayıt ekranı. Hesap oluşturma işlemlerini yönetir.

- **TutorialView.swift**: Yeni başlayanlar için öğretici içerik. Sudoku kuralları ve uygulama kullanımını anlatır.

- **TutorialOverlayView.swift**: Oyun içi yardım ve ipuçları gösteren katman. Adım adım rehberlik sağlar.

#### UI Bileşenleri
- **AnimatedSudokuLogo.swift**: Özel animasyonlu Sudoku logosu. Uygulama kimliğini görsel olarak temsil eder.
</details>

<details>
<summary><b>ViewModel Katmanı</b></summary>

- **SudokuViewModel.swift**: Oyun mantığını yöneten ana bileşen. Hücre seçimi, değer girişi, oyun durumu kontrolü, ipucu sistemi, zamanlayıcı yönetimi gibi kritik işlevleri içerir. Ayrıca kaydetme/yükleme işlemlerini ve skor hesaplamalarını koordine eder. (2300+ satır)

- **TimerViewModel.swift**: Oyun süresi takibi ve formatlaması için kullanılan bileşen. Duraklatma, devam etme ve sıfırlama gibi zamanlayıcı kontrollerini sağlar. (SudokuViewModel içinde implement edilmiş)

- **SettingsViewModel.swift**: Kullanıcı ayarlarının saklanması ve güncellenmesi işlemlerini yönetir. UserDefaults ile kalıcı ayarları işler. (SettingsView içinde implement edilmiş)
</details>

<details>
<summary><b>Model Katmanı</b></summary>

- **SudokuBoard.swift**: Sudoku tahtasının temel veri yapısını ve mantığını içerir (2600+ satır):
  - Tahta oluşturma algoritmaları
  - Geçerlilik kontrolleri (satır, sütun, blok)
  - Çözüm üretme ve doğrulama
  - Zorluk seviyesine göre ipucu ayarlama
  - Kalem işaretleri yönetimi
  - Çözüm stratejileri implementasyonu:
    - Naked Singles/Pairs/Triples
    - Hidden Singles/Pairs/Triples
    - Pointing Pairs/Triples
    - Box-Line Reduction
    - X-Wing ve Swordfish teknikleri
  - **Yeni:** Hızlandırılmış çözüm algoritmaları

- **ScoreManager.swift**: Yüksek skorları kaydetme, yükleme ve sıralama işlemlerini yürütür. CoreData ile entegre çalışır.

- **PersistenceController.swift**: CoreData altyapısını yöneten bileşen. Veritabanı bağlantısı, modelleme ve veri kalıcılığını sağlar.

- **SudokuModel.xcdatamodeld**: Ana veri modeli. SavedGame ve HighScore entity'lerini tanımlar.

- **ScoreModel.xcdatamodeld**: Skor yönetimi için özel veri modeli.
</details>

<details>
<summary><b>Yönetici Sınıflar (Managers)</b></summary>

- **SoundManager.swift**: Oyun seslerini yöneten sınıf. Ses efektlerinin yüklenmesi, oynatılması ve ses seviyesi kontrollerini sağlar.

- **PowerSavingManager.swift**: Pil durumu ve güç tasarrufu modu yönetimi. Düşük pil durumunda optimize edilmiş ayarlar sunar.

- **TutorialManager.swift**: Öğretici içerikleri ve yardım ipuçlarını yöneten sınıf. Adım adım rehberlik ve kullanıcı ilerlemesini takip eder.

- **LocalizationManager.swift**: **Yeni** Çoklu dil desteği ve dinamik dil değişimi
   - Uygulamanın farklı bölümlerinde yerelleştirilmiş içerik sağlama
   - Kullanıcı dil tercihlerinin saklanması ve uygulanması
</details>

<details>
<summary><b>Extensions</b></summary>

- **ColorExtension.swift**: Renk teması ve özelleştirmeleri için renk uzantıları. Arayüzde kullanılan özel renkleri tanımlar.

- **ViewTransitionExtension.swift**: Görünüm geçişleri ve animasyonları için uzantılar. Ekran değişimlerini özelleştirir.

- **DateExtension.swift**: Tarih formatlaması ve skor ekranlarında kullanılan zaman gösterimi için uzantılar.

- **NSManagedObjectExtensions.swift**: CoreData entity'leri için yardımcı metotlar içeren uzantılar.

- **AppLanguage+Extensions.swift**: **Yeni** Dil yapısı için ek özellikler ve yardımcı metotlar ekler.
</details>

<details>
<summary><b>Localizable Resources</b></summary>

- **Localizable.xcstrings**: **Yeni** Uygulama içindeki tüm metinlerin çoklu dil desteği için anahtar-değer çiftlerini içerir.
</details>

<details>
<summary><b>CoreDataModels ve Resources</b></summary>

- **SudokuModel.xcdatamodeld**: Uygulama veritabanı şemasını tanımlayan CoreData modeli. SavedGame ve HighScore entity'lerini içerir.
  
- **ScoreModel.xcdatamodeld**: Skorları saklamak için kullanılan ikincil CoreData modeli.

- **Assets.xcassets**: Uygulama ikonları, renkler ve görseller
  - PrimaryBlue, PrimaryGreen, PrimaryOrange, PrimaryPurple, PrimaryRed renk setleri
  - SudokuBackground, SudokuCell gibi UI renkleri
  - Sistem ikonları ve özel grafikler
</details>

## 🛠️ Teknik Detaylar

<details>
<summary><b>Mimari Yaklaşımlar</b></summary>

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

5. **LocalizationManager**: **Yeni**
   - Çoklu dil desteği ve dinamik dil değişimi
   - Uygulamanın farklı bölümlerinde yerelleştirilmiş içerik sağlama
   - Kullanıcı dil tercihlerinin saklanması ve uygulanması
</details>

<details>
<summary><b>Tahta Oluşturma Algoritması</b></summary>

1. Temel bir 9x9 desen oluşturma
2. Değerleri, satırları ve sütunları karıştırarak benzersiz tahtalar üretme
3. Zorluk seviyesine göre belirli sayıda hücreyi kaldırma
4. Tahtanın çözülebilirliğini doğrulama
5. Zorluk seviyesine göre çözüm stratejileri kontrolü:
   - Kolay: Naked Singles oranı ≥ 1.2
   - Orta: Hidden Singles ve Naked Pairs gerektirir
   - Zor: Hidden Pairs ve Pointing Pairs gerektirir
   - Uzman: X-Wing ve ileri teknikler gerektirir
6. **Yeni:** Optimizasyon teknikleri:
   - Backtracking ile hızlı çözüm kontrolü
   - Çözüm kontrol frekansının azaltılması
   - Daha verimli tahta doğrulama algoritmaları
</details>

<details>
<summary><b>Kalem İşaretleri ve Güç Tasarrufu</b></summary>

### Kalem İşaretleri (Pencil Marks)
- Oyuncuların bir hücreye yerleştirebilecekleri olası değerleri not etmelerini sağlar
- Her hücre için ayrı olası değerler seti tutulur
- Otomatik kalem işareti güncellemesi yapılabilir
- PencilMarksView ile kompakt ve okunabilir yerleşim

### Güç Tasarrufu Yönetimi
- PowerSavingManager sınıfı ile pil durumu takibi
- Düşük pil durumunda animasyonların ve arka plan işlemlerinin optimizasyonu
- Kullanıcıya pil tasarrufu modu hakkında bilgi ve seçenekler sunma
</details>

<details>
<summary><b>Veri Yönetimi ve Çoklu Dil Desteği</b></summary>

### Veri Yönetimi
- CoreData ile oyun durumu kaydedilir
- Yüksek skorlar yerel veritabanında saklanır
- Kullanıcı ayarları UserDefaults ile kalıcı hale getirilir
- NSPersistentContainer ve context yönetimi
- Background thread ve main thread senkronizasyonu

### Çoklu Dil Desteği (Yeni)
- Dinamik dil değişimi ve kullanıcı tercihlerinin saklanması
- Localizable.xcstrings ile merkezi çeviri yönetimi
- Desteklenen diller: İngilizce, Türkçe, Fransızca
- Yakında eklenecek: İspanyolca, Almanca, İtalyanca
- NSLocalizedString ve SwiftUI Text uzantıları ile kullanım
</details>

<details>
<summary><b>UI/UX Tasarım Prensipleri</b></summary>

- Tutarlı gradient arka planlar ve renk paletleri
- Modern kartlar ve konteynerler için gölge ve kenar tasarımları
- Zorluk seviyeselerine göre renk kodlaması
- Animasyonlu geçişler ve etkileşimler
- Erişilebilirlik için ayarlanabilir metin boyutları
- Karanlık/Aydınlık tema desteği
- **Yeni:** Kültürel uyarlama ve lokalizasyon desteği (adaptive layout)
</details>

## 🗺️ Yol Haritası

### Planlanan İyileştirmeler
- 🔲 Daha akıcı sayfa geçişleri
- 🔲 Hücre seçimi ve değer girişi için hoş animasyonlar
- ✅ Yeni başlayanlar için adım adım rehberlik
- ✅ Arka plan işlemlerini optimize etme
- 🔲 Gelişmiş pil tasarrufu modu
- 🔲 Çevrimiçi liderlik tablosu ve kullanıcı profilleri
- 🔲 İstatistik grafikleri ve detaylı oyun analizi
- ✅ Daha fazla dil desteği
- 🔲 Yapay zeka destekli ipucu sistemi
- 🔲 Daha fazla oyun modu ve özel zorluk seviyeleri

### Tamamlanan İyileştirmeler
- ✅ **Çoklu dil desteği**: İngilizce, Türkçe ve Fransızca dil desteği eklendi
- ✅ **Performans optimizasyonları**: Tahta oluşturma ve çözüm algoritmaları hızlandırıldı
- ✅ **Gelişmiş öğretici**: Sudoku kuralları ve stratejileri için adım adım rehberlik sistemi eklendi
- ✅ **Hata ayıklama iyileştirmeleri**: Debug çıktıları temizlendi ve performans arttırıldı
- ✅ **Kullanıcı arayüzü tutarlılığı**: Tüm ekranlarda tutarlı renk ve stillerin kullanımı sağlandı

## 🔧 Sorun Giderme

<details>
<summary><b>Bilinen Sorunlar ve Çözümleri</b></summary>

- CoreData modelleri (SudokuModel ve ScoreModel) arasındaki tutarsızlıklar nedeniyle yaşanan çökmeler düzeltildi
- PersistenceController, SudokuModel'i kullanacak şekilde güncellendi
- ScoreManager sınıfı, Score entity'si yerine HighScore entity'sini kullanacak şekilde düzenlendi
- NSManagedObject extension'larında getName(), getUsername() ve getEmail() metodları genel extension'a eklendi
- Yüksek CPU kullanımına neden olan animasyon döngüleri optimize edildi
- Bellek sızıntılarına neden olan capture list sorunları çözüldü
- **Yeni:** Bazı iPhone modellerde görülen dil seçimi sorunu düzeltildi
- **Yeni:** Çeviri eksiklikleri tamamlandı ve tutarlı hale getirildi
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
  <img src="screenshots/anasayfa.png" width="200" alt="Ana Menü"/>
  <img src="screenshots/oyunekranı.png" width="200" alt="Oyun Ekranı"/>
  <img src="screenshots/skor.png" width="200" alt="Skor Tablosu"/>
  <img src="screenshots/kayıtlı.png" width="200" alt="Kayıtlı Oyunlar"/>
  <img src="screenshots/ayarlar.png" width="200" alt="Ayarlar"/>
</div>

## 📝 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır - detaylar için [LICENSE.md](LICENSE.md) dosyasına bakın.

## 🙏 Teşekkürler

- SwiftUI ve Combine dokümantasyonu için Apple'a
- Sudoku algoritmaları için açık kaynak topluluğuna
- Sürekli geri bildirim sağlayan test kullanıcılarımıza
- Lokalizasyon desteği için dil uzmanlarımıza

## Firebase Entegrasyonu

### Genel Bakış

Sudoku uygulaması, bulut tabanlı veri senkronizasyonu ve kullanıcı kimlik doğrulama işlemleri için Firebase'i kullanmaktadır. Bu entegrasyon sayesinde kullanıcılar:

- Farklı cihazlar arasında oyun ilerlemelerini senkronize edebilir
- Kaydedilmiş oyunlarını çevrimiçi depolayabilir
- Skorlarını ve istatistiklerini güvenle saklayabilir
- İnternet bağlantısı olmadan oyun oynayabilir, internet bağlantısı sağlandığında veriler otomatik olarak senkronize edilir

### Kurulum

Firebase entegrasyonu için aşağıdaki adımlar izlenmiştir:

1. Xcode projesine Firebase SDK eklenmesi:
   ```swift
   // Package Dependencies olarak eklendi
   .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "10.0.0"))
   ```

2. Gerekli Firebase modüllerinin içe aktarılması:
   ```swift
   import FirebaseCore
   import FirebaseAuth
   import FirebaseFirestore
   import FirebaseStorage
   ```

3. Firebase'in yapılandırılması:
   ```swift
   // SudokuApp.swift (veya AppDelegate) içerisinde
   FirebaseApp.configure()
   ```

### Firebase Hizmetleri Kullanımı

#### Authentication (Kimlik Doğrulama)

Kullanıcı hesapları ve kimlik doğrulama işlemleri için `FirebaseAuth` kullanılmıştır:

```swift
// Kullanıcı girişi
Auth.auth().signIn(withEmail: email, password: password) { result, error in
    // Hata kontrolü ve kullanıcı bilgisi işleme
}

// Kullanıcı kaydı
Auth.auth().createUser(withEmail: email, password: password) { result, error in
    // Kullanıcı profili oluşturma
}

// Kullanıcı çıkışı
try? Auth.auth().signOut()
```

#### Firestore (Veritabanı)

Oyun verileri, istatistikler ve kullanıcı profilleri için `Firestore` kullanılmıştır:

```swift
let db = Firestore.firestore()

// Veri yükleme
db.collection("savedGames")
    .whereField("userId", isEqualTo: Auth.auth().currentUser?.uid ?? "")
    .getDocuments { snapshot, error in
        // Kaydedilmiş oyunları işleme
    }

// Veri kaydetme
db.collection("savedGames").document(gameId).setData([
    "userId": Auth.auth().currentUser?.uid ?? "",
    "boardState": encodedBoardState,
    "difficulty": difficulty.rawValue,
    "dateCreated": Timestamp(),
    "isCompleted": false
])

// Veri silme
db.collection("savedGames").document(gameId).delete()
```

#### Storage (Depolama)

Kullanıcı profil fotoğrafları için `FirebaseStorage` kullanılmıştır:

```swift
let storage = Storage.storage()
let storageRef = storage.reference().child("profileImages/\(userId).jpg")

// Resim yükleme
if let imageData = profileImage.jpegData(compressionQuality: 0.8) {
    storageRef.putData(imageData, metadata: nil) { metadata, error in
        // Yükleme işlemini kontrol etme
    }
}

// Resim indirme
storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
    if let imageData = data {
        let image = UIImage(data: imageData)
        // Resmi kullanıcı arayüzünde gösterme
    }
}
```

### Offline Kullanım ve Senkronizasyon

Firebase, internet bağlantısı olmadığında bile çalışabilir. Uygulama, çevrimdışı kullanım için aşağıdaki yapılandırmaları yapar:

```swift
// Firebase'in çevrimdışı kalıcılığını etkinleştirme
let settings = Firestore.firestore().settings
settings.isPersistenceEnabled = true
Firestore.firestore().settings = settings
```

Çevrimdışıyken yapılan değişiklikler, internet bağlantısı sağlandığında otomatik olarak senkronize edilir.

### Veri Modeli

Firebase'de aşağıdaki ana koleksiyonlar kullanılır:

- **users**: Kullanıcı profilleri ve ayarları
- **savedGames**: Kaydedilmiş oyunlar ve durumları
- **statistics**: Kullanıcı istatistikleri ve performans verileri
- **highScores**: Zorluk seviyesine göre en yüksek skorlar

### Güvenlik Kuralları

Firebase Firestore için güvenlik kuralları, verilerin yalnızca doğru kullanıcılar tarafından erişilebilmesini sağlar:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Kaydedilmiş oyunlar kullanıcıya özeldir
    match /savedGames/{gameId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
    
    // Kullanıcı verileri sadece kendi kullanıcısı tarafından okunabilir ve yazılabilir
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // İstatistikler kullanıcıya özeldir
    match /statistics/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Yüksek skorlar herkes tarafından okunabilir, ancak sadece doğrulanmış kullanıcılar tarafından yazılabilir
    match /highScores/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### Hata Yönetimi ve Geri Bildirim

Firebase işlemleri sırasında oluşabilecek hatalar için kapsamlı hata yönetimi uygulanmıştır:

```swift
// Örnek hata işleme
db.collection("savedGames").document(gameId).setData(gameData) { error in
    if let error = error {
        print("Oyun kaydedilirken hata oluştu: \(error.localizedDescription)")
        // Kullanıcıya hata bildirimi gösterme
    } else {
        print("Oyun başarıyla kaydedildi")
        // Başarı bildirimi gösterme
    }
}
```

### Performans Optimizasyonu

Veri transferini ve pil kullanımını optimize etmek için şu önlemler alınmıştır:

- Yalnızca gerekli verilerin indirilmesi için sorgu filtreleme
- Büyük veri kümeleri için sayfalama kullanımı
- Veri sınırlamaları ile ağ kullanımını azaltma
- Kullanıcı etkileşimine dayalı önbellek politikaları

### Veri Senkronizasyon Stratejisi

Veri senkronizasyonu şu stratejiye göre gerçekleştirilir:

1. Yerel veriler her zaman önceliklidir (hızlı erişim için)
2. Uygulama başlatıldığında ve düzenli aralıklarla Firebase ile senkronizasyon yapılır
3. Çakışma durumunda en son değiştirilen veri önceliklidir
4. Çevrimdışı değişiklikler kuyruklanır ve internet bağlantısı sağlandığında işlenir

---

<p align="center">
  <sub>Geliştirici: Necati Yıldırım © 2024</sub>
</p>
