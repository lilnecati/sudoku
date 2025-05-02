# Sudoku Uygulaması Tema Değişikliği Sistemi - Atomik Akış Analizi

Bu belge, Sudoku uygulamasındaki tema (açık/koyu mod) değişikliği sisteminin, SwiftUI'nin iç mekanizmaları, property wrapper'lar, Combine framework entegrasyonu ve dosyalar/bileşenler arası veri akışını **en detaylı seviyede** (atomik seviyede) analiz etmektedir.

## 1. Merkezi Durum Yönetimi: `ThemeManager` Sınıfı (`SudokuApp.swift`)

- **Tanım:** `class ThemeManager: ObservableObject`
    - **`ObservableObject` Protokolü:** Bu protokol, SwiftUI'ye bu sınıfın *izlenebilir* olduğunu bildirir. Sınıfın, durumu değiştiğinde güncellenmesi gereken görünümlere bildirim göndermesini sağlayan bir `objectWillChange` Combine Publisher'ı otomatik olarak sentezlemesini sağlar.
- **Konum:** `Sudoku/SudokuApp.swift`
- **Yaratılma & Yaşam Döngüsü:**
    - `@StateObject private var themeManager = ThemeManager()`: `SudokuApp` struct'ı içinde `@StateObject` property wrapper'ı kullanılarak yaratılır. `@StateObject`, `ThemeManager` örneğinin uygulama veya Scene yaşam döngüsü boyunca *yalnızca bir kez* yaratılmasını ve SwiftUI tarafından yönetilmesini garanti eder. `SudokuApp` struct'ı yeniden yaratılsa bile `ThemeManager` örneği korunur.
- **Sorumluluk:** Uygulamanın `darkMode`, `useSystemAppearance` ve bunlardan türetilen `colorScheme` durumunu merkezi olarak tutar ve yönetir.
- **Erişim Mekanizması:**
    - `.environmentObject(themeManager)`: `SudokuApp` içinde `StartupView`'a uygulanır. Bu modifier, yaratılan `ThemeManager` örneğini o görünüm hiyerarşisi için SwiftUI Ortamı'na (Environment) yerleştirir. Artık alt görünümler bu örneğe `@EnvironmentObject` ile erişebilir.
- **Özellikler (Properties) ve Mekanizmaları:**
    - `@AppStorage("darkMode") var darkMode: Bool`: 
        - **`@AppStorage` Wrapper'ı:** Bu wrapper, özelliğin değerini cihazın `UserDefaults.standard` deposundaki `"darkMode"` anahtarıyla senkronize eder.
        - **Okuma:** Özellik okunduğunda `UserDefaults.standard.bool(forKey: "darkMode")` çağrılır.
        - **Yazma:** Özelliğe yeni bir değer atandığında (`darkMode.toggle()` veya `darkMode = newValue`), wrapper değeri hem kendi içinde günceller hem de anında `UserDefaults.standard.set(newValue, forKey: "darkMode")` çağrısını yapar. `UserDefaults` değişiklikleri sisteme bildirilir (KVO veya benzeri mekanizmalarla, ancak bu SwiftUI katmanı altında kalır).
        - **`didSet` Tetiklemesi:** Değer değiştiğinde, **wrapper'ın kendisi değil, tanımlanan `didSet` bloğu çalışır**.
    - `@AppStorage("useSystemAppearance") var useSystemAppearance: Bool`: `darkMode` ile aynı mekanizmayla çalışır, `"useSystemAppearance"` anahtarını kullanır.
    - `@Published var colorScheme: ColorScheme?`: 
        - **`@Published` Wrapper'ı:** Bu wrapper, Combine framework entegrasyonunu sağlar. Her `@Published` özellik, içeren sınıfın `objectWillChange` Publisher'ına otomatik olarak bağlanır.
        - **Değişiklik Bildirimi:** Bu özelliğe yeni bir değer atandığında (`didSet` bloğu içinde `colorScheme = ...`), `@Published` wrapper'ı *otomatik olarak* `self.objectWillChange.send()` metodunu çağırır. Bu, Combine Publisher aracılığıyla bir değişiklik *olmak üzere olduğunu* yayınlar.
- **`didSet` Mantığı (Doğrudan Çalışan Kod):**
    - `darkMode` veya `useSystemAppearance` özellikleri `@AppStorage` tarafından güncellendiğinde, *hemen ardından* bu özelliklere eklenmiş `didSet` blokları çalışır:
    ```swift
    @AppStorage(...) var darkMode: Bool = false {
        didSet { // Bu blok AppStorage güncellemesinden sonra çalışır
            // useSystemAppearance ve güncel darkMode değerleri okunur
            colorScheme = useSystemAppearance ? nil : (darkMode ? .dark : .light)
            // colorScheme'e atama yapıldığı anda @Published tetiklenir -> objectWillChange.send()
        }
    }
    ```
- **`init()` Metodu:** `ThemeManager` örneği `@StateObject` tarafından *ilk kez* yaratıldığında çalışır. `@AppStorage` özellikleri zaten başlangıç değerlerini `UserDefaults`'tan okuyacağı için, `init` içinde `colorScheme`'i tekrar ayarlamak (`didSet` mantığı zaten başlangıçta çalışacaktır) genellikle gereksizdir veya `colorScheme`'in başlangıç değerini `init` içinde `UserDefaults` okuyarak ayarlamak daha doğru olabilir. Mevcut kodda `init` içinde doğrudan `colorScheme` ayarı yapılıyorsa, `@AppStorage`'ın başlangıç okuması ve `didSet` ile yarış durumu veya çift işlem olasılığına dikkat edilmelidir. (Mevcut koda göre `init` içinde ayarlanıyor.)
- **Metotlar (Methods):**
    - `func toggleDarkMode()`: Doğrudan `self.darkMode.toggle()` çağrısını yapar. Bu da yukarıda açıklandığı `@AppStorage` yazma -> `didSet` -> `@Published` güncelleme -> `objectWillChange` zincirini başlatır.

## 2. Ayarlar Arayüzü: `SettingsView` Yapısı (`SettingsView.swift`)

- **Tanım:** `struct SettingsView: View`
    - **`View` Protokolü:** Temel gereksinimi, hesaplanmış bir `body` özelliği sağlamaktır. `body`, görünümün içeriğini tanımlayan diğer `View`'leri döndürür.
- **Konum:** `Sudoku/View/SettingsView.swift`
- **`ThemeManager` Erişimi:**
    - `@EnvironmentObject var themeManager: ThemeManager`: Bu wrapper, SwiftUI Ortamı'ndan `ThemeManager` tipindeki nesneyi arar (bu nesne `SudokuApp.swift`'te `.environmentObject` ile sağlanmıştı). Eğer bulunamazsa uygulama çöker. SwiftUI, bu görünümü otomatik olarak alınan `themeManager` örneğinin `objectWillChange` Publisher'ına abone yapar.
- **Kullanıcı Etkileşimi (`Button` Actions -> `ThemeManager` Çağrısı):**
    - Bir `Button`'ın `action` bloğu çalıştırıldığında:
        - `themeManager.useSystemAppearance.toggle()` veya `themeManager.darkMode.toggle()`: Alınan `@EnvironmentObject` referansı (`themeManager`) üzerinden, `ThemeManager` sınıfının (`SudokuApp.swift` içindeki *tekil* örneğin) ilgili özelliğine erişilir ve değeri değiştirilir. Bu, doğrudan Bölüm 1'deki `@AppStorage` mekanizmasını tetikler.
- **Değişiklik İzleme (`.onChange` -> Lokal Aksiyonlar):**
    - `.onChange(of: themeManager.darkMode) { _, newValue in ... }`: Bu modifier, `themeManager` nesnesinin `darkMode` özelliğini izler. Değer değiştiğinde (ki bu değişiklik `objectWillChange` bildirimi sonrası SwiftUI tarafından tespit edilir), içindeki kapanış (closure) çalıştırılır. Bu, `SettingsView`'ın *kendi içinde* ek UI güncellemeleri yapmasına veya (gerekiyorsa) `themeManager.objectWillChange.send()` gibi manuel bildirimler göndermesine olanak tanır.
- **Akış Yönü (Kontrol):** `SettingsView.swift` (UI Event) -> `@EnvironmentObject` referansı -> `ThemeManager` örneği (`SudokuApp.swift`) -> Özellik Değişikliği.
- **Akış Yönü (Veri/Durum):** `ThemeManager` (`SudokuApp.swift`) -> `objectWillChange` -> SwiftUI -> `SettingsView.swift` (yeniden çizim tetiklenir).

## 3. Tema Uygulaması ve Yayılımı (`SudokuApp.swift` & SwiftUI Ortamı Mekanizması)

- **`SudokuApp` Yapısı (`SudokuApp.swift`):**
    - **`ThemeManager` Yaratımı & Enjeksiyonu:** Yukarıda açıklandı.
    - **`.preferredColorScheme()` Modifier'ı:**
        - **Uygulanma Yeri:** Genellikle Scene'in kök görünümüne (`StartupView` gibi) uygulanır.
        - **Çalışma Mekanizması:** Bu modifier, uygulandığı görünüm ve *altındaki tüm hiyerarşi* için SwiftUI Ortamı'ndaki `\.colorScheme` anahtarının değerini geçersiz kılar (override eder).
        - **Değer Okuma:** Değer olarak verilen ifade (`themeManager.colorScheme`) okunur. `themeManager` bir `ObservableObject` olduğu için, `colorScheme` değiştiğinde bu modifier'ın yeniden değerlendirilmesi tetiklenir.
        - **Ortam Ayarlama:** Hesaplanan değeri (`.dark`, `.light` veya `nil`) alır ve bu görünümden itibaren alt hiyerarşiye yayılacak olan `\.colorScheme` ortam değerini ayarlar.
- **SwiftUI Ortamı (Environment):**
    - **Dinamik Değer Deposu:** Ortam, bir görünüm hiyerarşisi boyunca aşağı doğru otomatik olarak aktarılan değerler koleksiyonudur (`\.colorScheme`, `\.locale`, `\.managedObjectContext` ve özel `.environmentObject`'lar gibi).
    - **`\.colorScheme` Yayılımı:** `.preferredColorScheme()` tarafından ayarlanan değer, bir alt görünüm kendi `.preferredColorScheme()` modifier'ını kullanmadığı sürece tüm alt görünümlere miras kalır.
    - **`ThemeManager` Yayılımı:** `.environmentObject(themeManager)` ile eklenen nesne, hiyerarşide aşağı doğru akar ve `@EnvironmentObject` ile yakalanabilir.

## 4. Renk Yönetimi (`ColorManager`, `Assets.xcassets` & Runtime Çözümlemesi)

- **`ColorManager` Yapısı (`SudokuApp.swift`):**
    - **Kullanım:** `static let` olarak tanımlandığı için, herhangi bir yerden `ColorManager.primaryBlue` gibi doğrudan çağrılarak renk değerine erişilir. Kendisi bir durum tutmaz.
- **`Assets.xcassets` (Proje Dosyası - Build Time & Runtime):**
    - **Build Time:** Derleme sırasında Xcode, Varlık Kataloğu'ndaki renk setlerini (Light/Dark varyantları ile) uygulamanın paketine dahil eder.
    - **Runtime Çözümleme:**
        - Kodda `Color("PrimaryBlue")` veya standart `Color.primary` gibi bir renk ifadesiyle karşılaşıldığında, bu ifade hemen belirli bir RGB değerine çözümlenmez.
        - SwiftUI'nin render (çizim) aşamasında, o anki görünümün miras aldığı `\.colorScheme` ortam değeri kontrol edilir.
        - Bu `\.colorScheme` değerine göre (`.dark` veya `.light`), işletim sisteminin UI framework'ü (UIKit veya AppKit altında çalışan CoreGraphics/QuartzCore katmanları) Varlık Kataloğu'ndan veya sistemin tanımlı renk paletinden uygun renk varyantını (RGB değerini) yükler.
        - Bu işlem, her çizim döngüsünde dinamik olarak gerçekleşir, bu yüzden tema değiştiğinde renkler otomatik olarak güncellenir.

## 5. Bileşenlerin Temaya Uyum Sağlaması (Çeşitli Görünüm Dosyaları - Render Aşaması)

- **Otomatik Uyum (Standart Bileşenler & Renkler):**
    - `Text`, `Image(systemName:)`, `Divider` gibi bileşenler ve `Color.primary`, `Color("AssetName")` gibi renkler kullanıldığında, SwiftUI'nin render motoru çizim yaparken güncel `\.colorScheme`'i dikkate alır ve uygun sistem görünümünü/rengini kullanır.
- **Manuel Uyum (`BackgroundView.swift` - `Canvas` Çizimi):**
    - **`body` Hesaplaması:** `BackgroundView`'ın `body`'si yeniden hesaplandığında, `@Environment(\.colorScheme)` güncel değeri içerir.
    - **Koşullu Mantık:** `if colorScheme == .dark` bloğu çalıştırılır.
    - **`Canvas` Çizimi:** `Canvas` kapanışı (closure) çalıştırılır. İçindeki `drawDarkModeGrid` fonksiyonu çağrılır.
    - **`GraphicsContext`:** Bu fonksiyon, `GraphicsContext` API'sini kullanarak belirli RGB değerleri veya `Color` nesneleri ile (ki bunlar da o anki `\.colorScheme`'e göre çözümlenir) çizgileri çizer.
- **Koşullu Stil (`GameView.swift` Header - Ternary Operatör):**
    - **`body` Hesaplaması:** `GameView`'ın `body`'si (veya `headerView`'ı) yeniden hesaplandığında, `@Environment(\.colorScheme)` güncel değeri içerir.
    - **Anlık Değerlendirme:** `.background(Circle().fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)))` ifadesi anlık olarak değerlendirilir. `colorScheme == .dark` kontrol edilir ve sonuç `true` ise `Color(.systemGray5)`, `false` ise `Color(.systemGray6)` kullanılır. Bu renkler de yine Varlık Kataloğu'ndan dinamik olarak çözümlenir.
- **Zorla Yeniden Çizim (`GameView.swift` -> `SudokuBoardView.swift` - View Identity):**
    - **`.onChange` Tetiklenmesi:** `GameView`, `themeManager`'dan gelen `objectWillChange` bildirimi sonrası yeniden çizilirken, `.onChange` modifier'ı `themeManager.darkMode` veya `useSystemAppearance`'daki değişikliği *tespit eder*.
    - **State Güncellemesi:** `.onChange` bloğu çalışır ve `GameView`'ın *kendi* `@State` değişkeni olan `boardKey`'e yeni bir `UUID` atanır.
    - **View Identity (Kimlik) Değişikliği:** SwiftUI, görünümleri karşılaştırırken ve güncellerken kimliklerini (identity) kullanır. `.id()` modifier'ı bir görünümün kimliğini açıkça belirler. `boardKey` değiştiğinde, `SudokuBoardView(.id(boardKey))` ifadesinin temsil ettiği görünümün kimliği değişmiş olur.
    - **Yıkım ve Yeniden Yaratım:** SwiftUI, kimliği değişen bir görünümü *güncellemek yerine*, eski görünüm örneğini tamamen hafızadan kaldırır (destroy) ve tamamen yeni bir `SudokuBoardView` örneği yaratır (init çağrılır), ardından bu yeni örneğin `body`'sini hesaplar. Bu, görünümün tüm iç durumunun sıfırlanmasını ve yeni temaya göre baştan çizilmesini garanti eder.

## 6. Tema Değişikliği Akışı (Dosyalar Arası Atomik Adımlar)

1.  **Kullanıcı Dokunması (`SettingsView.swift` - UI Event Loop):** Kullanıcı ekrana dokunur, işletim sistemi dokunmayı ilgili `Button`'a yönlendirir.
2.  **`Button` Action (`SettingsView.swift` -> `SudokuApp.swift` - Metot Çağrısı):** `Button` action'ı, `@EnvironmentObject` proxy'si üzerinden `ThemeManager` örneğinin (`SudokuApp.swift`) ilgili metodunu (`darkMode.toggle()`) çağırır.
3.  **`@AppStorage` Yazma (`SudokuApp.swift` -> `UserDefaults` - Disk I/O & Bildirim):** `@AppStorage` wrapper'ı özelliği günceller, `UserDefaults.standard.set()`'i çağırır (potansiyel disk yazma işlemi), `UserDefaults` değişikliği sisteme bildirir.
4.  **`didSet` Tetiklenir (`SudokuApp.swift` - Doğrudan Kod Çalıştırma):** `@AppStorage` güncellemesi biter bitmez, özelliğe bağlı `didSet` bloğu çalışır.
5.  **`@Published` Güncelleme (`SudokuApp.swift` - Bellek İçi Atama):** `didSet` bloğu, `ThemeManager` içindeki `colorScheme` özelliğine yeni değeri atar.
6.  **`objectWillChange` Bildirimi (`SudokuApp.swift` -> Combine -> SwiftUI):** `colorScheme`'e atama yapıldığı anda `@Published` wrapper'ı *eşzamanlı olarak* `ThemeManager`'ın `objectWillChange` Combine Publisher'ında `.send()` metodunu çağırır.
7.  **SwiftUI Aboneliği & View Invalidation (SwiftUI Mekanizması -> `SettingsView.swift`, `GameView.swift`...):** SwiftUI, `objectWillChange` sinyalini alır. Bu sinyale abone olan (`@EnvironmentObject` ile `ThemeManager`'ı izleyen) tüm görünümleri "geçersiz" (invalidated) olarak işaretler. Bu, bu görünümlerin bir sonraki UI güncelleme döngüsünde yeniden değerlendirilmesi gerektiği anlamına gelir.
8.  **`.preferredColorScheme()` Yeniden Değerlendirme (`SudokuApp.swift` -> SwiftUI Ortamı):** Geçersiz kılınan `StartupView` (veya modifier'ın uygulandığı görünüm) yeniden değerlendirilirken, `.preferredColorScheme()` modifier'ı `themeManager.colorScheme`'in güncel değerini okur ve SwiftUI Ortamı'ndaki `\.colorScheme` değerini günceller.
9.  **`\.colorScheme` Yayılımı (SwiftUI Ortamı Mekanizması):** Güncellenen `\.colorScheme` değeri, ortam aracılığıyla geçersiz kılınan alt görünümlere (`SettingsView`, `GameView`...) otomatik olarak yayılır.
10. **Görünüm Yeniden Çizimi (SwiftUI Diffing/Rendering -> Çeşitli Dosyalar):**
    - **`body` Çağrısı:** Geçersiz kılınan görünümlerin (`SettingsView`, `GameView`...) `body` özellikleri çağrılır.
    - **Ortam/State Okuma:** `body` içinde `@Environment(\.colorScheme)`, `@EnvironmentObject`, `@State` gibi değerler okunur (artık güncel değerleri içerirler).
    - **Varlık Çözümleme (Runtime -> `Assets.xcassets`):** `body` hesaplaması sırasında karşılaşılan `Color` nesneleri, güncel `\.colorScheme`'e göre çizim aşamasında doğru RGB değerlerine çözümlenir.
    - **`.onChange` Çalışması (`GameView.swift`):** `GameView` yeniden değerlendirilirken, `.onChange` `themeManager`'daki değişikliği algılar ve `boardKey` state'ini günceller.
    - **`.id()` ile Yeniden Yaratım (SwiftUI View Lifecycle -> `SudokuBoardView.swift`):** `boardKey` değişikliği, SwiftUI'nin `SudokuBoardView` için eski görünüm ağacını yıkıp yenisini yaratmasına neden olur.
11. **Ekrana Çizim (SwiftUI Render Motoru -> GPU):** SwiftUI, önceki ve yeni görünüm hiyerarşileri arasındaki farkı hesaplar (diffing) ve yalnızca değişen kısımları güncellemek üzere minimum çizim komutunu (örn. Metal/OpenGL komutları) GPU'ya gönderir.

Bu atomik seviyedeki analiz, basit bir toggle dokunuşunun SwiftUI, Combine ve işletim sistemi katmanları arasında nasıl bir dizi olayı tetikleyerek kullanıcı arayüzünü güncellediğini detaylandırmaktadır. 