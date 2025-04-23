# GitHub Packages - Sudoku Uygulaması

GitHub Packages, yazılım projelerinde kullanılan paketlerin barındırılması, yönetilmesi ve dağıtılması için entegre bir çözümdür. Bu dosya, Sudoku uygulaması için GitHub Packages kullanımı hakkında detaylı bilgi içerir.

## GitHub Packages Nedir?

GitHub Packages, projenizin bağımlılıklarını ve paketlerini doğrudan GitHub deposu ile birlikte barındırmanıza olanak tanıyan bir paket yönetim servisidir.

- **Entegre Paket Yönetimi**: Kodunuz ve paketleriniz aynı yerde (GitHub) bulunabilir
- **Çoklu Paket Formatı Desteği**: npm, Maven, RubyGems, Docker images ve daha fazlası desteklenir
- **Swift Package Manager** desteği ile iOS/macOS uygulamaları için idealdir
- **Güvenli Erişim Kontrolü**: GitHub izinleri ile paket erişimini yönetebilirsiniz
- **GitHub Actions** ile otomatik yayınlama ve dağıtım

## Sudoku Uygulamasında Paket Kullanımı

### Swift Package Manager (SPM) Yapılandırması

Sudoku uygulaması, Swift Package Manager kullanarak bağımlılıkları yönetir. Aşağıda, `Package.swift` dosyasında bulunan yapılandırma örneği verilmiştir:

```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SudokuApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "10.0.0")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "SudokuCore",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "SudokuCoreTests",
            dependencies: ["SudokuCore"]
        )
    ]
)
```

### Uygulama İçinde Kullanılan Paketler

#### Firebase Bileşenleri

| Bileşen | Kullanım Amacı | İlgili Dosyalar |
|---------|--------------|----------------|
| FirebaseAuth | Kullanıcı kimlik doğrulama | `AuthManager.swift`, `LoginView.swift`, `SignupView.swift` |
| FirebaseFirestore | Oyun verilerinin senkronizasyonu | `PersistenceController.swift`, `SudokuViewModel.swift` |
| FirebaseStorage | Kullanıcı profil fotoğrafları | `ProfileView.swift`, `UserManager.swift` |

#### Swift Collections

Collections paketi, Sudoku mantık uygulamasında kullanılan özelleştirilmiş veri yapıları için kullanılır. Özellikle `OrderedSet` ve `Deque` yapıları, aşağıdaki durumlar için faydalıdır:

- Hücre adaylarını yönetmek (OrderedSet)
- İpucu geçmişini saklamak (Deque)
- Geri alma/ileri alma işlemleri için hareket geçmişi (Deque)

## GitHub Packages ile Kendi Paketlerinizi Yayınlama

Sudoku uygulamasının belirli bileşenlerini (örneğin SudokuCore) bağımsız bir paket olarak yayınlamak isterseniz, aşağıdaki adımları izleyebilirsiniz:

1. **Paket Yapılandırması Oluşturma**:
   - Gerekli `Package.swift` dosyasını oluşturun
   - Bağımlılıkları ve hedefleri (targets) tanımlayın
   - Sürüm numarasını belirleyin

2. **GitHub'a Push**:
   ```bash
   git add .
   git commit -m "Paket yapılandırması eklendi"
   git push origin main
   ```

3. **Sürüm Etiketi Oluşturma**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

4. **GitHub Packages'ta Yayınlama**:
   - GitHub Actions kullanılarak otomatik yayınlama
   - Veya GitHub web arayüzünden manuel olarak paket oluşturma

5. **Diğer Projelerde Kullanma**:
   ```swift
   .package(url: "https://github.com/username/SudokuCore.git", .upToNextMajor(from: "1.0.0"))
   ```

## GitHub Packages Avantajları

1. **Entegre İş Akışı**: Kod ve paketler aynı platformda
2. **Özel Paketler**: Herkese açık veya özel depolarla çalışabilir
3. **Otomatik Dağıtım**: GitHub Actions ile CI/CD süreçlerine entegrasyon
4. **Sürüm Kontrolü**: Git workflow'u ile doğal sürüm yönetimi
5. **Güvenlik**: Güvenlik açıklarını tespit etmek için Dependabot entegrasyonu

## Paket Versiyonlama Stratejisi

Sudoku uygulaması, Semantic Versioning (SemVer) stratejisini benimsemektedir:

- **Major (X.0.0)**: Geriye dönük uyumlu olmayan API değişiklikleri
- **Minor (0.X.0)**: Geriye dönük uyumlu olan yeni özellikler
- **Patch (0.0.X)**: Hata düzeltmeleri

Bu yaklaşım, bağımlılık yönetimini kolaylaştırır ve hem geliştiriciler hem de kullanıcılar için kararlılık sağlar.

---

Bu dokümantasyon, Sudoku uygulamasının GitHub Packages entegrasyonu hakkında genel bir bakış sağlamaktadır. Spesifik teknik ayrıntılar ve güncellenen bilgiler için, GitHub deposundaki ilgili dokümantasyona başvurabilirsiniz. 