//  SoundManager.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 29.03.2025.
//

import Foundation
import AVFoundation
import SwiftUI
import AudioToolbox  // AudioServices için

/// Sudoku uygulaması için ses efektlerini yöneten sınıf
class SoundManager: ObservableObject {
    // MARK: - Properties
    // Singleton pattern
    static let shared = SoundManager()
    
    // Ses oynatıcıları - her ses türü için ayrı
    private var numberInputPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?
    private var correctPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var navigationPlayer: AVAudioPlayer?
    
    // AppStorage ile entegre ses ayarı
    @AppStorage("enableSoundEffects") private var enableSoundEffects: Bool = true
    
    // Ses seviyesi
    @AppStorage("soundVolume") private var defaultVolume: Double = 0.7 // Varsayılan ses seviyesi
    
    private var powerManager = PowerSavingManager.shared
    
    private init() {
        // Sound ayarları için ilk yapılandırma
        print("🎵 SoundManager başlatılıyor...")
        
        // Audio session'ı konfigüre et
        configureAudioSession()
        
        // Observer'ları kaydet
        registerForSystemNotifications()
        
        // Ses dosyalarını yükle
        loadSounds()
    }
    
    deinit {
        // Uygulama sonlandığında gözlemcileri temizle
        NotificationCenter.default.removeObserver(self)
    }
    
    private func registerForSystemNotifications() {
        // Sistem olaylarını dinle
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("📱 Uygulama arka plana geçti - ses sistemi devre dışı bırakılıyor")
        deactivateAudioSession()
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("📱 Uygulama ön plana geçti - ses sistemi yeniden başlatılıyor")
        configureAudioSession()
        resetAudioPlayers()
    }
    
    /// Ses kesintileri olduğunda çağrılır (örn. telefon araması)
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Ses kesintisi başladı - ses sistemi duraklatıldı")
            // Ses oynatma işlemini durdur
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            print("🔈 Ses kesintisi sona erdi - ses sistemi yeniden başlatılıyor")
            
            if options.contains(.shouldResume) {
                // Ses sistemini yeniden aktif et
                configureAudioSession()
            }
            
        @unknown default:
            print("⚠️ Bilinmeyen ses kesintisi durumu")
        }
    }
    
    /// Ses yönlendirme değişiklikleri olduğunda çağrılır (kulaklık vb.)
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("🎧 Yeni ses cihazı bağlandı")
            // Örn. kulaklık takıldı
            
        case .oldDeviceUnavailable:
            print("🔈 Ses cihazı çıkarıldı - hoparlöre geçildi")
            // Örn. kulaklık çıkarıldı
            
        default:
            print("🔄 Ses yönlendirme değişti: \(reason.rawValue)")
        }
        
        // Ses sistemini güvenli şekilde yeniden yapılandır
        configureAudioSession()
    }
    
    /// Audio session'ı yapılandırır
    private func configureAudioSession() {
        do {
            // Mevcut durumu kontrol et
            let audioSession = AVAudioSession.sharedInstance()
            
            // Ses kategorisini ve modu ayarla - .playback kategorisi .ambient'ten daha güvenilir
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // Session'ı aktif et
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ Audio session başarıyla yapılandırıldı (Kategori: playback)")
        } catch {
            print("❌ Audio session yapılandırılamadı: \(error.localizedDescription)")
        }
    }
    
    /// Audio session'ı devre dışı bırakır
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Audio session devre dışı bırakıldı")
        } catch {
            print("❌ Audio session devre dışı bırakılamadı: \(error.localizedDescription)")
        }
    }
    
    /// Audio session'ı dışarıdan yapılandırmak için public metot (ses çalmadan)
    func setupAudioSession() {
        do {
            // Mevcut durumu kontrol et
            let audioSession = AVAudioSession.sharedInstance()
            
            // Ses kategorisini ve modu ayarla - .playback kategorisi .ambient'ten daha güvenilir
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // Session'ı aktif et ama sistem sesi çalmadan
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ Ses sistemi sessizce yapılandırıldı")
        } catch {
            print("❌ Audio session yapılandırılamadı: \(error.localizedDescription)")
        }
    }
    
    /// Tüm ses dosyalarını yükler
    private func loadSounds() {
        // Ses dosyalarını yükle
        print("🔊 Ses dosyaları yükleniyor...")
        
        // Her oynatıcı için yeni bir örnek oluştur
        resetAudioPlayers()
    }
    
    /// Tüm ses oynatıcılarını sıfırla
    func resetAudioPlayers() {
        numberInputPlayer = nil
        errorPlayer = nil
        correctPlayer = nil
        completionPlayer = nil
        navigationPlayer = nil
        
        // Ses oynatıcıları için sistem sesleri atamak için ikinci bir kontrol ekle
        // Bu, ses oynatıcıları oluşturulamadığında bile ses çalabilmemizi sağlar
        print("🔄 Tüm ses oynatıcıları sıfırlandı")
    }
    
    /// Belirtilen isimli ses dosyasını yükler
    func loadSound(named name: String, ofType type: String) -> AVAudioPlayer? {
        print("🔊 loadSound çağrıldı: \(name).\(type)")
        do {
            let result = try createAudioPlayer(named: name, extension: type)
            print("✅ Ses yüklendi: \(name).\(type) - URL: \(result.url?.lastPathComponent ?? "bilinmeyen")")
            return result
        } catch {
            print("❌ Ses dosyası yüklenirken hata: \(name).\(type) - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Farklı yolları ve uzantıları deneyen daha güvenli bir ses dosyası yükleme metodu
    private func createAudioPlayer(named name: String, extension fileExt: String) throws -> AVAudioPlayer {
        // Hem Resources/Sounds/ hem de kök dizini kontrol et
        let paths = [
            "Resources/Sounds/\(name)",  // Resources/Sounds altında
            "Sounds/\(name)",           // Sounds klasöründe (farklı dizin yapısı için)
            name                        // Kök dizinde
        ]
        
        // Uzantı alternatifleri - önce belirtilen, sonra alternatif
        var extensions = [fileExt]
        if fileExt == "mp3" {
            extensions.append("wav")
        } else if fileExt == "wav" {
            extensions.append("mp3")
        }
        
        // Tüm yolları ve uzantıları dene
        for path in paths {
            for ext in extensions {
                // URL'den yüklemeyi dene
                if let url = Bundle.main.url(forResource: path, withExtension: ext) {
                    do {
                        let fileExists = FileManager.default.fileExists(atPath: url.path)
                        if fileExists {
                            print("✅ Ses dosyası bulundu: \(path).\(ext)")
                            
                            // Format tespiti
                            let data = try Data(contentsOf: url)
                            let hexSignature = data.prefix(4).map { String(format: "%02X", $0) }.joined()
                            
                            // Format bazlı fileTypeHint seçimi
                            var fileTypeHint: String? = nil
                            if hexSignature.hasPrefix("5249") {  // "RIFF" (WAV)
                                fileTypeHint = AVFileType.wav.rawValue
                                print("🔄 Format: WAV (RIFF) algılandı")
                            } else if hexSignature.hasPrefix("4944") || hexSignature.hasPrefix("FFFA") || hexSignature.hasPrefix("FFFB") {
                                fileTypeHint = AVFileType.mp3.rawValue
                                print("🔄 Format: MP3 algılandı")
                            }
                            
                            // Veriyi ve doğru format bilgisini kullanarak oynatıcı oluştur
                            do {
                                let player = try AVAudioPlayer(data: data, fileTypeHint: fileTypeHint)
                                player.prepareToPlay()
                                player.volume = Float(defaultVolume)
                                print("✅ Ses oynatıcı başarıyla oluşturuldu: \(path).\(ext)")
                                return player
                            } catch {
                                print("❌ AVAudioPlayer oluşturulamadı: \(error.localizedDescription)")
                                // Diğer uzantı veya yol ile devam et
                            }
                        }
                    } catch {
                        print("❌ \(path).\(ext) yüklenirken hata: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Hiçbir şekilde yüklenemedi, hata fırlat
        print("❌ Hiçbir şekilde yüklenemedi: \(name).\(fileExt)")
        throw NSError(domain: "SoundManager", 
                     code: 1001, 
                     userInfo: [NSLocalizedDescriptionKey: "Ses dosyası bulunamadı veya yüklenemedi: \(name).\(fileExt)"])
    }
    
    /// Ses kaynakları kontrol etme - debug amaçlı
    func checkSoundResources() {
        print("🔍 TÜM SES KAYNAKLARI KONTROL EDİLİYOR")
        
        // Uygulama içinde bulunan tüm ses dosyalarını bul
        let fileManager = FileManager.default
        guard let bundleURL = Bundle.main.resourceURL else {
            print("❌ Bundle URL bulunamadı")
            return
        }
        
        // Sesler için bakılacak alanlar
        let extensions = ["wav", "mp3"]
        let searchPaths = [
            bundleURL.path,
            bundleURL.appendingPathComponent("Sounds").path,
            bundleURL.appendingPathComponent("Resources").path,
            bundleURL.appendingPathComponent("Resources/Sounds").path
        ]
        
        print("🔍 Arama yapılacak yollar: \(searchPaths)")
        
        // Tüm dizinleri dolaş
        for path in searchPaths {
            if fileManager.fileExists(atPath: path) {
                print("✅ Var olan dizin: \(path)")
                do {
                    // Bu dizindeki tüm dosyaları al
                    let fileURLs = try fileManager.contentsOfDirectory(atPath: path)
                    
                    // Ses dosyalarını filtrele
                    let soundFiles = fileURLs.filter { filePath in
                        return extensions.contains { ext in
                            filePath.hasSuffix(".\(ext)")
                        }
                    }
                    
                    if soundFiles.isEmpty {
                        print("⚠️ \(path) içinde ses dosyası bulunamadı")
                    } else {
                        print("✅ \(path) içinde bulunan ses dosyaları: \(soundFiles)")
                        
                        // Dosya detaylarını göster
                        for soundFile in soundFiles {
                            let fullPath = URL(fileURLWithPath: path).appendingPathComponent(soundFile).path
                            do {
                                let attrs = try fileManager.attributesOfItem(atPath: fullPath)
                                let fileSize = attrs[.size] as? UInt64 ?? 0
                                print("📊 '\(soundFile)' - Boyut: \(fileSize) bytes")
                            } catch {
                                print("⚠️ '\(soundFile)' özellikleri okunamadı: \(error)")
                            }
                        }
                    }
                } catch {
                    print("⚠️ \(path) içeriği okunamadı: \(error)")
                }
            } else {
                print("⚠️ Dizin mevcut değil: \(path)")
            }
        }
        
        // Ana bundle içindeki ses kaynaklarını listele
        print("\n🔍 Bundle kaynaklarını doğrudan kontrol ediyorum:")
        
        // Test edilecek ses dosyaları
        let testSounds = ["tap", "error", "correct", "completion", "number_tap"]
        
        for soundName in testSounds {
            for ext in extensions {
                if let resourcePath = Bundle.main.path(forResource: soundName, ofType: ext) {
                    print("✅ '\(soundName).\(ext)' bulundu: \(resourcePath)")
                    
                    // Dosya boyutunu kontrol et
                    do {
                        let attrs = try fileManager.attributesOfItem(atPath: resourcePath)
                        let fileSize = attrs[.size] as? UInt64 ?? 0
                        print("📊 '\(soundName).\(ext)' - Boyut: \(fileSize) bytes")
                        
                        // Dosyayı AVAudioPlayer ile açmaya çalış
                        do {
                            let url = URL(fileURLWithPath: resourcePath)
                            let testPlayer = try AVAudioPlayer(contentsOf: url)
                            print("✅ '\(soundName).\(ext)' AVAudioPlayer ile açılabildi - Süre: \(testPlayer.duration) sn")
                        } catch {
                            print("❌ '\(soundName).\(ext)' AVAudioPlayer ile açılamadı: \(error)")
                        }
                    } catch {
                        print("⚠️ '\(soundName).\(ext)' dosya özellikleri okunamadı: \(error)")
                    }
                } else {
                    print("❌ '\(soundName).\(ext)' bulunamadı")
                }
            }
        }
    }
    
    /// Ses seviyesini günceller ve tüm oynatıcılara uygular
    func updateVolumeLevel(_ volume: Double) {
        print("🔊 Ses seviyesi güncelleniyor: \(volume)")
        defaultVolume = volume
        
        // Tüm oynatıcılara yeni ses seviyesini uygula
        numberInputPlayer?.volume = Float(defaultVolume)
        errorPlayer?.volume = Float(defaultVolume)
        correctPlayer?.volume = Float(defaultVolume)
        completionPlayer?.volume = Float(defaultVolume)
        navigationPlayer?.volume = Float(defaultVolume)
        
        // NOT: Artık ses seviyesi değiştiğinde oynatıcıları sıfırlamıyoruz
        // Bu şekilde kafa karışıklığı ve yanlış sesler çalınması önlenmiş olacak
        
        // Ses değiştiğinde bildir
        NotificationCenter.default.post(name: NSNotification.Name("SoundVolumeChangedNotification"), object: nil)
        
        // Ses efekti çal (düşük seviyede)
        playVolumeChangeIndicator()
    }
    
    /// Ses seviyesini sessizce günceller - test sesi çalmadan (kaydırıcı hareketi için)
    func updateVolumeLevelQuietly(_ volume: Double) {
        print("🔊 Ses seviyesi sessizce güncelleniyor: \(volume)")
        defaultVolume = volume
        
        // Tüm oynatıcılara yeni ses seviyesini uygula
        numberInputPlayer?.volume = Float(defaultVolume)
        errorPlayer?.volume = Float(defaultVolume)
        correctPlayer?.volume = Float(defaultVolume)
        completionPlayer?.volume = Float(defaultVolume)
        navigationPlayer?.volume = Float(defaultVolume)
        
        // Bildirim gönder ama ses çalma
        NotificationCenter.default.post(name: NSNotification.Name("SoundVolumeChangedNotification"), object: nil)
    }
    
    /// Ses seviyesi değiştiğini göstermek için kısa bir ses çalar
    private func playVolumeChangeIndicator() {
        guard canPlaySound() else { return }
        
        // Sistem sesi DEVRE DIŞI - iOS sistem sesleri sorunlarını engellemek için
        /*
        // Kısa ve hafif bir sistem tık sesi çal
        if defaultVolume > 0.0 {
            // Ses seviyesine göre farklı sesler
            if defaultVolume < 0.3 {
                AudioServicesPlaySystemSound(1100) // Daha hafif
            } else if defaultVolume < 0.6 {
                AudioServicesPlaySystemSound(1104) // Orta seviye
            } else {
                AudioServicesPlaySystemSound(1103) // Daha güçlü
            }
        }
        */
        
        // Kendi ses dosyalarımızı kullan
        if defaultVolume > 0.0 {
            // Ses için tap.wav sesini kullan (number_tap değil)
            print("🔊 Ses seviyesi değişikliği için tap sesi çalınıyor")
            
            if let player = loadSound(named: "tap", ofType: "wav") {
                player.volume = Float(defaultVolume)
                player.play()
            } else {
                print("❌ tap.wav yüklenemedi, ses çalınamadı")
            }
        }
    }
    
    /// Ses ayarlarını günceller
    func updateSoundSettings(enabled: Bool) {
        print("🔊 Ses ayarları güncelleniyor: \(enabled ? "Açık" : "Kapalı")")
        enableSoundEffects = enabled
        
        // Ses ayarı değiştiğinde oynatıcıları sıfırla
        if enabled {
            resetAudioPlayers()
        }
    }
    
    // Geçici çözüm - system sound olarak bir test sesi çal
    func playBasicTestSound() {
        print("🔊 Temel ses testi çalınıyor...")
        guard canPlaySound() else { 
            print("❌ Ses ayarları kapalı olduğu için test sesi çalınamıyor")
            return 
        }
        
        // Ses seviyesine göre test sesleri
        if defaultVolume <= 0.0 {
            print("❌ Ses seviyesi 0 olduğu için test sesi çalınamıyor")
            return
        }
        
        // Test için birkaç farklı ses çalarak kullanıcıya deneyim sağla
        DispatchQueue.global().async {
            // Önce tap sesi çal (number_tap yerine)
            if let player = self.loadSound(named: "tap", ofType: "wav") {
                player.volume = Float(self.defaultVolume)
                player.play()
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            if let player = self.loadSound(named: "correct", ofType: "mp3") ?? self.loadSound(named: "correct", ofType: "wav") {
                player.volume = Float(self.defaultVolume)
                player.play()
                Thread.sleep(forTimeInterval: 1.0)
            } else {
                // Doğru sesi yüklenemezse alternatif olarak kullan
                if let player = self.loadSound(named: "tap", ofType: "wav") {
                    player.volume = Float(self.defaultVolume)
                    player.play()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            // Son olarak hata sesi
            Thread.sleep(forTimeInterval: 0.2)
            if let player = self.loadSound(named: "error", ofType: "wav") {
                player.volume = Float(self.defaultVolume)
                player.play()
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                // Hata sesi yüklenemezse alternatif olarak kullan
                if let player = self.loadSound(named: "tap", ofType: "wav") {
                    player.volume = Float(self.defaultVolume)
                    player.play()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        
        print("✅ Test sesi çalındı")
    }
    
    /// Kullanıcı ses ayarlarını kontrol eder
    private func canPlaySound() -> Bool {
        return enableSoundEffects
    }
    
    /// Sayı girildiğinde çalan ses
    func playNumberInputSound() {
        print("🎵 playNumberInputSound çağrıldı")
        guard canPlaySound() else { return }
        
        // Sistem sesi DEVRE DIŞI - çift ses sorununu çözmek için
        // AudioServicesPlaySystemSound(1104)
        
        // Klasik yöntem - kendi ses dosyamızı kullanalım
        if numberInputPlayer == nil {
            numberInputPlayer = loadSound(named: "number_tap", ofType: "wav")
            
            // Yükleme başarısız olursa log tut
            if numberInputPlayer == nil {
                print("❌ number_tap.wav yüklenemedi, alternatif ses çalınamayacak")
            }
        }
        
        guard let player = numberInputPlayer else { 
            print("❌ Number input player nil olduğu için ses çalınamıyor")
            return 
        }
        
        // İsmi ve formatı log'la
        print("✅ playNumberInputSound: \(player.url?.lastPathComponent ?? "bilinmeyen")")
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    /// Hatalı bir hamle yapıldığında çalan ses
    func playErrorSound() {
        print("🎵 playErrorSound çağrıldı")
        guard canPlaySound() else { return }
        
        // System sound DEVRE DIŞI
        // AudioServicesPlaySystemSound(1521) // Standart hata sesi
        
        // Klasik yöntem
        if errorPlayer == nil {
            errorPlayer = loadSound(named: "error", ofType: "wav") ?? loadSound(named: "error", ofType: "mp3")
        }
        
        guard let player = errorPlayer else { return }
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    /// Doğru bir hamle yapıldığında çalan ses
    func playCorrectSound() {
        print("🎵 playCorrectSound çağrıldı")
        guard canPlaySound() else { return }
        
        // System sound DEVRE DIŞI
        // AudioServicesPlaySystemSound(1519) // Standart başarı sesi
        
        // Klasik yöntem
        if correctPlayer == nil {
            correctPlayer = loadSound(named: "correct", ofType: "wav") ?? loadSound(named: "correct", ofType: "mp3")
        }
        
        guard let player = correctPlayer else { return }
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    /// Oyun başarıyla tamamlandığında çalan ses
    func playCompletionSound() {
        guard canPlaySound() else { return }
        
        // System sound DEVRE DIŞI
        // AudioServicesPlaySystemSound(1103) // Posta sesi
        
        // Klasik yöntem
        if completionPlayer == nil {
            completionPlayer = loadSound(named: "completion", ofType: "wav") ?? loadSound(named: "completion", ofType: "mp3")
        }
        
        guard let player = completionPlayer else { return }
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    /// Menü ve gezinme sesi
    func playNavigationSound() {
        print("🎵 playNavigationSound çağrıldı")
        guard canPlaySound() else { return }
        
        // Tüm sistem sesleri devre dışı bırakıldı
        // Sadece kendi ses dosyamızı kullan
        
        // Klasik yöntem - kendi ses dosyamızı kullanalım
        if navigationPlayer == nil {
            print("⚠️ Navigation player oluşturuluyor - doğrudan tap.wav kullanılacak")
            // Burada doğrudan "tap" dosyasını kullan, alternatif araması yapma
            navigationPlayer = loadSound(named: "tap", ofType: "wav")
            
            // Yükleme başarısız olursa log tut
            if navigationPlayer == nil {
                print("❌ tap.wav yüklenemedi, ses çalınamayacak")
            }
        }
        
        guard let player = navigationPlayer else { 
            print("❌ Navigation player nil olduğu için ses çalınamıyor")
            return 
        }
        
        // İsmi ve formatı log'la
        print("✅ playNavigationSound: \(player.url?.lastPathComponent ?? "bilinmeyen")")
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    // Sesle ilgili eylemleri daha basitleştirmek için bu fonksiyonu kullan
    func executeSound(_ action: SoundAction) {
        switch action {
        case .tap:
            // TAP için özel bir print ekleyerek tam olarak ne çağrıldığını görelim
            print("🔍 executeSound(.tap) çağrıldı -> doğrudan playNavigationSound çağrılıyor")
            playNavigationSound()
        case .numberInput:
            // NUMBER_INPUT için özel bir print ekleyerek ne çağrıldığını görelim
            print("🔍 executeSound(.numberInput) çağrıldı -> playNumberInputSound çağrılıyor")
            playNumberInputSound()
        case .correct:
            playCorrectSound()
        case .error:
            playErrorSound()
        case .completion:
            playCompletionSound()
        case .vibrate:
            // Titreşim özelliğini koru, kullanıcının dokunsal geri bildirimi hissetmesi önemli
            if UIDevice.current.userInterfaceIdiom == .phone {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        case .test:
            playBasicTestSound()
        case .erase:
            playEraseSound()
        }
    }
    
    // Ses eylemlerini enum olarak tanımla
    enum SoundAction {
        case tap           // Menü ve navigasyon sesleri
        case numberInput   // Sayı girişi
        case correct       // Doğru hamle 
        case error         // Yanlış hamle
        case completion    // Oyunu bitirme
        case vibrate       // Titreşim
        case test          // Test sesi
        case erase         // Silme sesi
    }
    
    /// Silme tuşu için ses
    func playEraseSound() {
        guard canPlaySound() else { return }
        
        // Erase ses dosyasını çal
        if let erasePlayer = loadSound(named: "erase", ofType: "wav") {
            if erasePlayer.isPlaying { erasePlayer.stop() }
            erasePlayer.currentTime = 0
            erasePlayer.volume = Float(defaultVolume)
            erasePlayer.play()
        } else {
            // Erase ses dosyası yoksa tap ses dosyasını kullan
            if let player = loadSound(named: "tap", ofType: "wav") {
                player.volume = Float(defaultVolume)
                player.play()
            }
            // System sound devre dışı
            // AudioServicesPlaySystemSound(1155) // Alternatif silme sesi
        }
    }
} 
