# Sudoku Ses Dosyaları

Bu klasör Sudoku uygulamasında kullanılan ses efektlerini içerir. Sağlıklı bir ses deneyimi için tüm dosyalar:

1. MP3 formatında olmalıdır
2. Düşük boyutlu (tipik olarak 20-100KB) olmalıdır
3. Kısa ve etkileyici olmalıdır (0.5-2 saniye)

## Gerekli Dosyalar

Aşağıdaki ses dosyalarını edinip bu klasöre eklemeniz gerekiyor:

1. `number_tap.mp3` - Sayı girildiğinde çalınan kısa tıklama sesi
2. `error.mp3` - Yanlış bir hamle yapıldığında çalan uyarı sesi
3. `correct.mp3` - Doğru bir hamle yapıldığında çalan pozitif ses
4. `completion.mp3` - Sudoku tamamlandığında çalan kutlama sesi
5. `tap.mp3` - Menü ve diğer UI etkileşimleri için hafif bir tıklama sesi

## Nereden Bulabilirsiniz?

Bu ses dosyalarını aşağıdaki kaynaklardan edinebilirsiniz:

1. [Freesound](https://freesound.org/) - Creative Commons lisanslı ücretsiz sesler
2. [OpenGameArt](https://opengameart.org/) - Oyun geliştirme için ücretsiz varlıklar
3. [ZapSplat](https://www.zapsplat.com/) - Ücretsiz ve premium ses efektleri

Not: Ses dosyaları belirli lisans koşullarına tabi olabilir, ticari bir uygulama için kullanmadan önce lisans koşullarını kontrol edin. 

## Ses Entegrasyon Algoritması

Sudoku uygulamasında ses entegrasyonu aşağıdaki yapı ile gerçekleştirilmiştir:

### SoundManager Yapısı

1. **SoundManager Sınıfı**:
   - `shared` adında singleton bir instance kullanıyor
   - Ses ayarları için `@AppStorage` ile kullanıcı tercihlerini saklıyor
   - Ses seviyesi `defaultVolume` ile kontrol ediliyor (Double tipinde, 0-1 arası değer)

2. **Ses Oynatıcıları**:
   - Farklı ses türleri için ayrı `AVAudioPlayer` nesneleri:
     ```swift
     private var numberInputPlayer: AVAudioPlayer?
     private var errorPlayer: AVAudioPlayer?
     private var correctPlayer: AVAudioPlayer?
     private var completionPlayer: AVAudioPlayer?
     private var navigationPlayer: AVAudioPlayer?
     ```

3. **Ses Çalma Fonksiyonları**:
   - `playNumberInputSound()`: Sayı girildiğinde çalınan ses
   - `playErrorSound()`: Hatalı hamle yapıldığında çalınan ses
   - `playCorrectSound()`: Doğru hamle yapıldığında çalınan ses
   - `playCompletionSound()`: Oyun tamamlandığında çalınan ses
   - `playNavigationSound()`: Menü ve gezinme sesi

4. **Basitleştirilmiş Arayüz**:
   - `executeSound(_ action: SoundAction)` fonksiyonu ile kolay kullanım
   - `SoundAction` enum değerleri: `.tap`, `.numberInput`, `.correct`, `.error`, `.completion`, `.vibrate`, `.test`

### SudokuViewModel Entegrasyonu

1. **Doğru/Yanlış Hamle Sesleri**:
   - `setValueAtSelectedCell()` metodunda:
     ```swift
     // Doğru ve yanlış hamlelere göre ses çal
     if isCorrect {
         // Doğru hamle ses efekti
         SoundManager.shared.executeSound(.correct)
     } else {
         // Yanlış hamle ses efekti
         SoundManager.shared.executeSound(.error)
     }
     ```

2. **Oyun Tamamlama Sesi**:
   ```swift
   if board.isBoardFilledEnough() {
       gameState = .completed
       stopTimer()
       
       // Tamamlama sesi çal
       SoundManager.shared.executeSound(.completion)
   }
   ```

### Ses Optimizasyonları

1. **System Sound API**:
   - Bazı sesler için `AudioServicesPlaySystemSound()` kullanılıyor
   - Daha tutarlı, hafif ve düşük gecikmeli

2. **Güvenli Ses Yükleme**:
   - Farklı ses formatlarını (MP3, WAV) destekler
   - Ses dosyası bulunamazsa alternatif formatları dener
   - Hata durumlarında sisteme yerleşik seslere geri döner

3. **Performans İyileştirmeleri**:
   - Ses dosyaları uygun şekilde önbelleğe alınır
   - Boyutları optimize edilir (20-100KB arası)
   - Audio session yönetimi otomatik yapılır 