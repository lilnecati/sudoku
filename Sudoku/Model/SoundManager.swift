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
    
    // Player nesnelerini önden yükleme için
    private var tapPlayer: AVAudioPlayer?
    private var numberInputPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?
    private var correctPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var navigationPlayer: AVAudioPlayer?
    private var erasePlayer: AVAudioPlayer?
    
    // Log ayarı - varsayılan olarak kapalı
    @AppStorage("isLoggingEnabled") private var isLoggingEnabled: Bool = false
    
    // AppStorage ile entegre ses ayarı
    @AppStorage("enableSoundEffects") private var enableSoundEffects: Bool = true
    
    // Ses seviyesi
    @AppStorage("soundVolume") private var defaultVolume: Double = 0.7 // Varsayılan ses seviyesi
    
    private var powerManager = PowerSavingManager.shared
    
    private init() {
        log("SoundManager başlatılıyor...")
        
        // Audio session ayarları
        setupAudioSession()
        
        // Sesleri önceden yükle
        preloadSounds()
        
        log("SoundManager başlatıldı")
        
        // Ses seviyesi değişim bildirimini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolumeChange),
            name: NSNotification.Name("SoundVolumeChangedNotification"),
            object: nil
        )
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
        log("📱 Uygulama arka plana geçti - ses sistemi devre dışı bırakılıyor")
        deactivateAudioSession()
    }
    
    @objc private func handleAppWillEnterForeground() {
        log("📱 Uygulama ön plana geçti - ses sistemi yeniden başlatılıyor")
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
            log("🔇 Ses kesintisi başladı - ses sistemi duraklatıldı")
            // Ses oynatma işlemini durdur
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            log("🔈 Ses kesintisi sona erdi - ses sistemi yeniden başlatılıyor")
            
            if options.contains(.shouldResume) {
                // Ses sistemini yeniden aktif et
                configureAudioSession()
            }
            
        @unknown default:
            log("⚠️ Bilinmeyen ses kesintisi durumu")
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
            log("🎧 Yeni ses cihazı bağlandı")
            // Örn. kulaklık takıldı
            
        case .oldDeviceUnavailable:
            log("🔈 Ses cihazı çıkarıldı - hoparlöre geçildi")
            // Örn. kulaklık çıkarıldı
            
        default:
            log("🔄 Ses yönlendirme değişti: \(reason.rawValue)")
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
            
            log("✅ Audio session başarıyla yapılandırıldı (Kategori: playback)")
        } catch {
            logError("Audio session yapılandırılamadı: \(error.localizedDescription)")
        }
    }
    
    /// Audio session'ı devre dışı bırakır
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            log("🔇 Audio session devre dışı bırakıldı")
        } catch {
            logError("Audio session devre dışı bırakılamadı: \(error.localizedDescription)")
        }
    }
    
    /// Audio session'ı dışarıdan yapılandırmak için public metot (ses çalmadan)
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            log("✅ Audio session başarıyla yapılandırıldı")
        } catch {
            logError("Audio session yapılandırma hatası: \(error.localizedDescription)")
        }
    }
    
    /// Tüm ses dosyalarını yükler
    private func loadSounds() {
        // Ses dosyalarını yükle
        log("🔊 Ses dosyaları yükleniyor...")
        
        // Tüm ses oynatıcılarını sıfırla - memorydeki sesleri temizler
        resetAudioPlayers()
    }
    
    /// Tüm ses oynatıcılarını sıfırla - memorydeki sesleri temizler
    func resetAudioPlayers() {
        log("🔄 Tüm ses oynatıcıları sıfırlanıyor...")
        tapPlayer = nil
        numberInputPlayer = nil
        errorPlayer = nil
        correctPlayer = nil
        completionPlayer = nil
        navigationPlayer = nil
        erasePlayer = nil
        
        // Tüm sesleri tekrar yükle - önbelleğe al
        preloadSounds()
    }
    
    // Sık kullanılan sesleri önden yükle
    private func preloadSounds() {
        // Ses açıksa yükle
        if canPlaySound() {
            log("🔊 Ses dosyaları önceden yükleniyor...")
            
            // Rakam sesi
            numberInputPlayer = loadSound(named: "number_tap", ofType: "wav")
            
            // Silme sesi önbelleğe al
            erasePlayer = loadSound(named: "erase", ofType: "wav")
            if erasePlayer == nil {
                log("⚠️ erase.wav yüklenemedi, silme işleminde tap sesi kullanılacak")
                erasePlayer = loadSound(named: "tap", ofType: "wav")
            }
            
            // Doğru/yanlış sesleri
            errorPlayer = loadSound(named: "error", ofType: "wav")
            correctPlayer = loadSound(named: "correct", ofType: "mp3") ?? loadSound(named: "correct", ofType: "wav")
            
            // Bitiş sesi
            completionPlayer = loadSound(named: "completion", ofType: "wav")
            
            // Navigasyon sesi olarak tap kullan
            navigationPlayer = loadSound(named: "tap", ofType: "wav")
            
            log("✅ Ses dosyaları yüklendi")
        } else {
            log("⚠️ Ses kapalı olduğu için önden yükleme yapılmadı")
        }
    }
    
    /// Belirtilen isimli ses dosyasını yükler
    func loadSound(named name: String, ofType type: String) -> AVAudioPlayer? {
        log("🔊 loadSound çağrıldı: \(name).\(type)")
        do {
            let result = try createAudioPlayer(named: name, extension: type)
            log("✅ Ses yüklendi: \(name).\(type) - URL: \(result.url?.lastPathComponent ?? "bilinmeyen")")
            return result
        } catch {
            logError("Ses dosyası yüklenirken hata: \(name).\(type) - \(error.localizedDescription)")
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
                            log("✅ Ses dosyası bulundu: \(path).\(ext)")
                            
                            // Format tespiti
                            let data = try Data(contentsOf: url)
                            let hexSignature = data.prefix(4).map { String(format: "%02X", $0) }.joined()
                            
                            // Format bazlı fileTypeHint seçimi
                            var fileTypeHint: String? = nil
                            if hexSignature.hasPrefix("5249") {  // "RIFF" (WAV)
                                fileTypeHint = AVFileType.wav.rawValue
                                log("�� Format: WAV (RIFF) algılandı")
                            } else if hexSignature.hasPrefix("4944") || hexSignature.hasPrefix("FFFA") || hexSignature.hasPrefix("FFFB") {
                                fileTypeHint = AVFileType.mp3.rawValue
                                log("🔄 Format: MP3 algılandı")
                            }
                            
                            // Veriyi ve doğru format bilgisini kullanarak oynatıcı oluştur
                            do {
                                let player = try AVAudioPlayer(data: data, fileTypeHint: fileTypeHint)
                                player.prepareToPlay()
                                player.volume = Float(defaultVolume)
                                log("✅ Ses oynatıcı başarıyla oluşturuldu: \(path).\(ext)")
                                return player
                            } catch {
                                logError("AVAudioPlayer oluşturulamadı: \(error.localizedDescription)")
                                // Diğer uzantı veya yol ile devam et
                            }
                        }
                    } catch {
                        logError("\(path).\(ext) yüklenirken hata: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Hiçbir şekilde yüklenemedi, hata fırlat
        logError("Hiçbir şekilde yüklenemedi: \(name).\(fileExt)")
        throw NSError(domain: "SoundManager", 
                     code: 1001, 
                     userInfo: [NSLocalizedDescriptionKey: "Ses dosyası bulunamadı veya yüklenemedi: \(name).\(fileExt)"])
    }
    
    /// Ses kaynakları kontrol etme - debug amaçlı
    func checkSoundResources() {
        log("🔍 TÜM SES KAYNAKLARI KONTROL EDİLİYOR")
        
        // Uygulama içinde bulunan tüm ses dosyalarını bul
        let fileManager = FileManager.default
        guard let bundleURL = Bundle.main.resourceURL else {
            log("❌ Bundle URL bulunamadı")
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
        
        log("🔍 Arama yapılacak yollar: \(searchPaths)")
        
        // Tüm dizinleri dolaş
        for path in searchPaths {
            if fileManager.fileExists(atPath: path) {
                log("✅ Var olan dizin: \(path)")
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
                        log("⚠️ \(path) içinde ses dosyası bulunamadı")
                    } else {
                        log("✅ \(path) içinde bulunan ses dosyaları: \(soundFiles)")
                        
                        // Dosya detaylarını göster
                        for soundFile in soundFiles {
                            let fullPath = URL(fileURLWithPath: path).appendingPathComponent(soundFile).path
                            do {
                                let attrs = try fileManager.attributesOfItem(atPath: fullPath)
                                let fileSize = attrs[.size] as? UInt64 ?? 0
                                log("📊 '\(soundFile)' - Boyut: \(fileSize) bytes")
                            } catch {
                                logError("'\(soundFile)' özellikleri okunamadı: \(error)")
                            }
                        }
                    }
                } catch {
                    logError("\(path) içeriği okunamadı: \(error)")
                }
            } else {
                log("⚠️ Dizin mevcut değil: \(path)")
            }
        }
        
        // Ana bundle içindeki ses kaynaklarını listele
        log("\n�� Bundle kaynaklarını doğrudan kontrol ediyorum:")
        
        // Test edilecek ses dosyaları
        let testSounds = ["tap", "error", "correct", "completion", "number_tap"]
        
        for soundName in testSounds {
            for ext in extensions {
                if let resourcePath = Bundle.main.path(forResource: soundName, ofType: ext) {
                    log("✅ '\(soundName).\(ext)' bulundu: \(resourcePath)")
                    
                    // Dosya boyutunu kontrol et
                    do {
                        let attrs = try fileManager.attributesOfItem(atPath: resourcePath)
                        let fileSize = attrs[.size] as? UInt64 ?? 0
                        log("📊 '\(soundName).\(ext)' - Boyut: \(fileSize) bytes")
                        
                        // Dosyayı AVAudioPlayer ile açmaya çalış
                        do {
                            let url = URL(fileURLWithPath: resourcePath)
                            let testPlayer = try AVAudioPlayer(contentsOf: url)
                            log("✅ '\(soundName).\(ext)' AVAudioPlayer ile açılabildi - Süre: \(testPlayer.duration) sn")
                        } catch {
                            logError("'\(soundName).\(ext)' AVAudioPlayer ile açılamadı: \(error)")
                        }
                    } catch {
                        logError("'\(soundName).\(ext)' dosya özellikleri okunamadı: \(error)")
                    }
                } else {
                    log("❌ '\(soundName).\(ext)' bulunamadı")
                }
            }
        }
    }
    
    /// Ses seviyesini günceller ve tüm oynatıcılara uygular
    func updateVolumeLevel(_ volume: Double) {
        log("🔊 Ses seviyesi güncelleniyor: \(volume)")
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
        log("🔊 Ses seviyesi sessizce güncelleniyor: \(volume)")
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
            log("🔊 Ses seviyesi değişikliği için tap sesi çalınıyor")
            
            if let player = loadSound(named: "tap", ofType: "wav") {
                player.volume = Float(defaultVolume)
                player.play()
            } else {
                logError("tap.wav yüklenemedi, ses çalınamadı")
            }
        }
    }
    
    /// Ses ayarlarını günceller
    func updateSoundSettings(enabled: Bool) {
        log("🔊 Ses ayarları güncelleniyor: \(enabled ? "Açık" : "Kapalı")")
        enableSoundEffects = enabled
        
        // Ses ayarı değiştiğinde oynatıcıları sıfırla
        if enabled {
            resetAudioPlayers()
        }
    }
    
    // Geçici çözüm - system sound olarak bir test sesi çal
    func playBasicTestSound() {
        log("🔊 Temel ses testi çalınıyor...")
        guard canPlaySound() else { 
            log("❌ Ses ayarları kapalı olduğu için test sesi çalınamıyor")
            return 
        }
        
        // Ses seviyesine göre test sesleri
        if defaultVolume <= 0.0 {
            log("❌ Ses seviyesi 0 olduğu için test sesi çalınamıyor")
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
        
        log("✅ Test sesi çalındı")
    }
    
    /// Kullanıcı ses ayarlarını kontrol eder
    private func canPlaySound() -> Bool {
        return enableSoundEffects
    }
    
    /// Sayı girildiğinde çalan ses
    func playNumberInputSound() {
        log("🎵 playNumberInputSound çağrıldı")
        guard canPlaySound() else { return }
        
        // Sistem sesi DEVRE DIŞI - çift ses sorununu çözmek için
        // AudioServicesPlaySystemSound(1104)
        
        // Klasik yöntem - kendi ses dosyamızı kullanalım
        if numberInputPlayer == nil {
            numberInputPlayer = loadSound(named: "number_tap", ofType: "wav")
            
            // Yükleme başarısız olursa log tut
            if numberInputPlayer == nil {
                log("❌ number_tap.wav yüklenemedi, alternatif ses çalınamayacak")
            }
        }
        
        guard let player = numberInputPlayer else { 
            log("❌ Number input player nil olduğu için ses çalınamıyor")
            return 
        }
        
        // İsmi ve formatı log'la
        log("✅ playNumberInputSound: \(player.url?.lastPathComponent ?? "bilinmeyen")")
        
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        player.play()
    }
    
    /// Hatalı bir hamle yapıldığında çalan ses
    func playErrorSound() {
        log("🎵 playErrorSound çağrıldı")
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
        log("🎵 playCorrectSound çağrıldı")
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
        log("🎵 playNavigationSound çağrıldı")
        guard canPlaySound() else { return }
        
        // Tüm sistem sesleri devre dışı bırakıldı
        // Sadece kendi ses dosyamızı kullan
        
        // Klasik yöntem - kendi ses dosyamızı kullanalım
        if navigationPlayer == nil {
            log("⚠️ Navigation player oluşturuluyor - doğrudan tap.wav kullanılacak")
            // Burada doğrudan "tap" dosyasını kullan, alternatif araması yapma
            navigationPlayer = loadSound(named: "tap", ofType: "wav")
            
            // Yükleme başarısız olursa log tut
            if navigationPlayer == nil {
                log("❌ tap.wav yüklenemedi, ses çalınamayacak")
            }
        }
        
        guard let player = navigationPlayer else { 
            log("❌ Navigation player nil olduğu için ses çalınamıyor")
            return 
        }
        
        // İsmi ve formatı log'la
        log("✅ playNavigationSound: \(player.url?.lastPathComponent ?? "bilinmeyen")")
        
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
            log("🔍 executeSound(.tap) çağrıldı -> doğrudan playNavigationSound çağrılıyor")
            playNavigationSound()
        case .numberInput:
            // NUMBER_INPUT için özel bir print ekleyerek ne çağrıldığını görelim
            log("🔍 executeSound(.numberInput) çağrıldı -> playNumberInputSound çağrılıyor")
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
        log("�� playEraseSound çağrıldı")
        guard canPlaySound() else { return }
        
        // Erase ses dosyasını çal - önceden yüklenmiş oynatıcıyı kullan
        if erasePlayer == nil {
            erasePlayer = loadSound(named: "erase", ofType: "wav")
            if erasePlayer == nil {
                erasePlayer = loadSound(named: "tap", ofType: "wav")
            }
        }
        
        guard let player = erasePlayer else { 
            log("❌ Erase player nil olduğu için ses çalınamıyor")
            return 
        }
        
        // Mevcut oynatma durumunu kontrol et ve reset
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.volume = Float(defaultVolume)
        
        // Asenkron olarak değil, direkt burada çal
        player.play()
        
        // Log çıktısı
        log("✅ playEraseSound: \(player.url?.lastPathComponent ?? "bilinmeyen")")
    }
    
    // Ses seviyesi değiştiğinde çağrılan fonksiyon
    @objc private func handleVolumeChange(notification: Notification) {
        log("🔊 Ses seviyesi değişikliği bildirimi alındı")
        // Ses seviyesi değiştiğinde gerekli ayarlamaları yap
        // Tüm aktif ses oynatıcılarının ses seviyesini güncelle
        numberInputPlayer?.volume = Float(defaultVolume)
        errorPlayer?.volume = Float(defaultVolume)
        correctPlayer?.volume = Float(defaultVolume)
        completionPlayer?.volume = Float(defaultVolume)
        navigationPlayer?.volume = Float(defaultVolume)
        erasePlayer?.volume = Float(defaultVolume)
    }
    
    // MARK: - Log Yardımcı Metotları
    
    /// Loglama ayarının açılıp/kapatılması için
    func toggleLogging(_ enabled: Bool) {
        isLoggingEnabled = enabled
        log("Loglama \(enabled ? "açıldı" : "kapatıldı")")
    }
    
    /// Basit log fonksiyonu
    private func log(_ message: String) {
        guard isLoggingEnabled else { return }
        print("🔊 SoundManager: \(message)")
    }
    
    /// Hata log fonksiyonu - her zaman gösterilir
    private func logError(_ message: String) {
        print("❌ SoundManager Hatası: \(message)")
    }
} 
