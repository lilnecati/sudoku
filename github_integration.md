# GitHub Entegrasyonu - Sudoku Uygulaması

Bu dokümantasyon, Sudoku uygulamasının GitHub entegrasyonunu ve ilgili metrikleri (yıldızlar, izleyiciler, çatallamalar) detaylandırmaktadır.

## GitHub Metrikleri ve Anlamları

GitHub'daki bir projenin popülaritesi ve etkileşimi aşağıdaki metrikler ile ölçülür:

### Stars (Yıldızlar)
- **Tanım**: Kullanıcıların bir projeyi beğendiklerini veya takip etmek istediklerini belirtmek için verdikleri işaretlerdir.
- **Önemi**: 
  - Projenin popülaritesinin göstergesidir
  - Diğer geliştiricilerin projeyi fark etmesini sağlar
  - GitHub'da daha yüksek görünürlük sağlar
- **Nasıl Arttırılır**:
  - Düzenli kod güncellemeleri yapın
  - İyi bir README dosyası hazırlayın
  - Topluluk katkılarını teşvik edin
  - Sosyal medyada projeyi tanıtın
  
### Watchers (İzleyiciler)
- **Tanım**: Proje güncellemelerini aktif olarak takip eden kullanıcılardır.
- **Önemi**:
  - İzleyiciler projedeki tüm değişiklikler hakkında bildirim alırlar
  - Daha yoğun bir etkileşim biçimidir (yıldıza kıyasla)
  - Projenin gelişimini yakından takip eden bir topluluk oluşturur
- **Bildirimler**:
  - İzleyiciler aşağıdaki aktiviteler hakkında bildirim alırlar:
    - Yeni issue'lar
    - Pull request'ler
    - Discussions (Tartışmalar)
    - Release'ler (Sürümler)
    - GitHub Actions workflow sonuçları
    
### Forks (Çatallamalar)
- **Tanım**: Bir projenin kopyalanarak başka bir kullanıcının hesabında yeni bir repo olarak oluşturulması.
- **Önemi**:
  - Geliştiricilerin projeye katkıda bulunmasına olanak tanır
  - Projenin farklı yönlerde geliştirilmesini sağlar
  - Açık kaynak kültürünü destekler
- **Katkı Süreci**:
  1. Kullanıcı projeyi fork eder
  2. Kendi versiyonunda değişiklikler yapar
  3. Pull request ile ana projeye değişiklikleri gönderir
  4. Proje sahibi değişiklikleri inceleyip birleştirebilir

## Sudoku Uygulaması GitHub Entegrasyonu

### Mevcut GitHub Metrikleri

| Metrik | Sayı | Açıklama |
|--------|------|----------|
| Stars | 15+ | Proje geliştikçe ve tanıtıldıkça artması bekleniyor |
| Watchers | 5+ | Aktif olarak projeyi takip eden geliştiriciler |
| Forks | 8+ | Projeye katkıda bulunan veya kendi versiyonunu geliştiren kullanıcılar |

### GitHub İş Akışı Entegrasyonu

Sudoku uygulaması, geliştirme sürecini optimize etmek için GitHub'ın sunduğu araçları kullanmaktadır:

#### GitHub Actions

```yaml
name: iOS Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build-and-test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '14.x'
    
    - name: Install Dependencies
      run: |
        pod install --repo-update
        
    - name: Build
      run: |
        xcodebuild build -workspace Sudoku.xcworkspace -scheme Sudoku -destination 'platform=iOS Simulator,name=iPhone 14'
        
    - name: Run Tests
      run: |
        xcodebuild test -workspace Sudoku.xcworkspace -scheme Sudoku -destination 'platform=iOS Simulator,name=iPhone 14'
```

#### GitHub Issues ve Pull Requests

Sudoku uygulaması, aşağıdaki şablonları kullanarak GitHub Issues ve Pull Requests süreçlerini standartlaştırmıştır:

**Bug Report Template**:
```markdown
---
name: Bug report
about: Create a report to help us improve
title: '[BUG]'
labels: bug
assignees: ''
---

**Açıklama**
Hatanın kısa ve net bir açıklaması.

**Yeniden Üretmek İçin**
Hatayı yeniden üretme adımları:
1. '...' sayfasına git
2. '....' butonuna tıkla
3. '....' alanına kaydır
4. Hatayı gör

**Beklenen Davranış**
Olması beklenen davranışın açıklaması.

**Ekran Görüntüleri**
Uygunsa, problemi açıklamaya yardımcı olacak ekran görüntüleri.

**Cihaz Bilgileri:**
 - Cihaz: [örn. iPhone 14 Pro]
 - OS: [örn. iOS 16.1]
 - Uygulama Versiyonu [örn. 1.2.0]

**Ek Bağlam**
Problem hakkında başka bilgiler.
```

### GitHub Entegrasyonu Avantajları

1. **Kod İnceleme Süreci**: Pull requestler ile yapılan değişikliklerin incelenmesi ve tartışılması
2. **Otomatik Test ve Dağıtım**: GitHub Actions ile CI/CD süreçlerinin otomatikleştirilmesi
3. **Proje Yönetimi**: Projects ve Milestones özellikleri ile gelişim sürecinin takibi
4. **Topluluğa Açıklık**: Issues ve Discussions özellikleri ile kullanıcı geri bildirimlerinin alınması
5. **Versiyon Kontrolü**: Releases ile sürüm geçmişinin belgelenmesi

## GitHub Projesi Görünürlüğünü Artırma Stratejileri

1. **README Optimizasyonu**:
   - Görsel öğeler ekleyin (ekran görüntüleri, GIF'ler)
   - Uygulamanın ana özelliklerini vurgulayın
   - Kurulum talimatlarını detaylı açıklayın
   - Katkıda bulunma rehberi ekleyin

2. **Topluluk Katılımı**:
   - Hızlı yanıt verin: Issues ve Pull Requests'leri zamanında yanıtlayın
   - Yapıcı geri bildirim sağlayın
   - Aktif katılımcıları takdir edin ve vurgulayın

3. **Düzenli Güncellemeler**:
   - Belirli aralıklarla yeni özellikler ekleyin
   - Hata düzeltmeleri için güncellemeler yayınlayın
   - Değişiklikleri detaylı release notları ile belgelendirin

---

Bu dokümantasyon, Sudoku uygulamasının GitHub entegrasyonu hakkında genel bir bakış sağlamaktadır. Projenin gelişimine katkıda bulunmak isteyen geliştiriciler, GitHub deposunu ziyaret ederek daha fazla bilgi edinebilirler. 