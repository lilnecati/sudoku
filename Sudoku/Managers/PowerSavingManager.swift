import SwiftUI
import Combine
import Foundation
import UIKit
import AudioToolbox

/// Güç tasarrufu modunu yöneten sınıf
class PowerSavingManager: ObservableObject {
    // Singleton örneği
    static let shared = PowerSavingManager()
    
    // AppStorage değişkenleri
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    
    // Güç tasarrufu durumu
    @Published var powerSavingMode: Bool = UserDefaults.standard.bool(forKey: "powerSavingMode") {
        didSet {
            UserDefaults.standard.set(powerSavingMode, forKey: "powerSavingMode")
        }
    }
    
    @Published var autoPowerSaving: Bool = UserDefaults.standard.bool(forKey: "autoPowerSaving") {
        didSet {
            UserDefaults.standard.set(autoPowerSaving, forKey: "autoPowerSaving")
        }
    }
    
    // Yüksek performans modu - güç tasarrufunu geçersiz kılar
    @Published var highPerformanceMode: Bool = UserDefaults.standard.bool(forKey: "highPerformanceMode") {
        didSet {
            UserDefaults.standard.set(highPerformanceMode, forKey: "highPerformanceMode")
            // Yüksek performans aktifse, güç tasarrufunu devre dışı bırak
            if highPerformanceMode {
                powerSavingMode = false
                powerSavingLevel = .off
            }
        }
    }
    
    // GPU hızlandırma modu - varsayılan olarak aktif ve kapatılamaz
    @AppStorage("enableGPUAcceleration") var enableGPUAcceleration: Bool = true {
        didSet {
            // Her zaman aktif olacak şekilde zorla
            if !enableGPUAcceleration {
                enableGPUAcceleration = true
            }
            NotificationCenter.default.post(name: NSNotification.Name("GPUAccelerationChanged"), object: nil)
        }
    }
    
    // Pil seviyesi ve şarj durumu
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var isCharging: Bool = false
    
    // Düşük pil eşikleri - kademeli optimizasyon için
    private let criticalBatteryThreshold: Float = 0.15 // %15
    private let lowBatteryThreshold: Float = 0.25 // %25
    private let mediumBatteryThreshold: Float = 0.40 // %40
    
    // Otomatik güç tasarrufu durumu
    @Published private(set) var isAutoPowerSavingActive: Bool = false
    
    // Cancellable
    private var cancellables = Set<AnyCancellable>()
    
    // Kullanıcı etkileşimlerini sınırlandırmak için kullanılacak özellikler
    @Published private(set) var isThrottling: Bool = false
    private var throttleTimer: Timer?
    private let throttleDuration: TimeInterval = 0.1 // 100ms
    
    // Özel başlatıcı
    private init() {
        // Pil seviyesi izleme
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Başlangıç değerlerini ayarla
        updateBatteryStatus()
        
        // Varsayılan olarak güç tasarrufu modunu etkinleştir (CPU kullanımını düşürmek için)
        if !UserDefaults.standard.bool(forKey: "powerSavingModeInitialized") {
            powerSavingMode = true
            powerSavingLevel = .high // Maksimum performans için high seviyeye çıkarıldı
            autoPowerSaving = true
            enableGPUAcceleration = true // Varsayılan olarak GPU hızlandırma aktif
            UserDefaults.standard.set(true, forKey: "powerSavingModeInitialized")
            UserDefaults.standard.set(true, forKey: "powerSavingMode")
            UserDefaults.standard.set(true, forKey: "autoPowerSaving")
            UserDefaults.standard.set(true, forKey: "enableGPUAcceleration")
        }
        
        // CPU kullanımını düşürmek için hali hazırda aktif seviyeyi yükselt
        if powerSavingMode && powerSavingLevel != .high {
            powerSavingLevel = .high
        }
        
        // GPU hızlandırmayı her zaman etkinleştir
        enableGPUAcceleration = true
        
        // Pil durumu değişikliklerini izle
        NotificationCenter.default
            .publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryStatus()
            }
            .store(in: &cancellables)
    }
    
    // Pil durumunu güncelle
    private func updateBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        // Otomatik güç tasarrufu kontrolü
        checkAutoPowerSaving()
    }
    
    // Güç tasarrufu modu seviyesi
    @Published private(set) var powerSavingLevel: PowerSavingLevel = .off
    
    // Güç tasarrufu seviyeleri
    enum PowerSavingLevel: Int, CaseIterable {
        case off = 0
        case low = 1
        case medium = 2
        case high = 3
        
        var displayName: String {
            switch self {
            case .off: return "Kapalı"
            case .low: return "Düşük"
            case .medium: return "Orta"
            case .high: return "Yüksek"
            }
        }
    }
    
    // Otomatik güç tasarrufu kontrolü - kademeli
    private func checkAutoPowerSaving() {
        if !autoPowerSaving || isCharging {
            // Otomatik mod kapalı veya şarj oluyorsa
            if isAutoPowerSavingActive {
                powerSavingMode = false
                powerSavingLevel = .off
                isAutoPowerSavingActive = false
            }
            return
        }
        
        // Pil seviyesine göre kademeli güç tasarrufu
        var newLevel: PowerSavingLevel = .off
        
        if batteryLevel <= criticalBatteryThreshold {
            // Kritik seviye - maksimum tasarruf
            newLevel = .high
        } else if batteryLevel <= lowBatteryThreshold {
            // Düşük seviye - yüksek tasarruf
            newLevel = .medium
        } else if batteryLevel <= mediumBatteryThreshold {
            // Orta seviye - hafif tasarruf
            newLevel = .low
        }
        
        // Güç tasarrufu seviyesini güncelle
        if newLevel != .off {
            powerSavingMode = true
            powerSavingLevel = newLevel
            isAutoPowerSavingActive = true
        } else if isAutoPowerSavingActive {
            // Pil seviyesi yeterli, güç tasarrufunu kapat
            powerSavingMode = false
            powerSavingLevel = .off
            isAutoPowerSavingActive = false
        }
    }
    
    // Güç tasarrufu modunu manuel olarak değiştir
    func togglePowerSavingMode() {
        powerSavingMode.toggle()
        
        // Manuel değişiklik yapıldığında otomatik modu sıfırla
        if powerSavingMode {
            isAutoPowerSavingActive = false
            powerSavingLevel = .medium // Varsayılan olarak orta seviye
        } else {
            powerSavingLevel = .off
        }
        
        // Titreşim açıksa titreşimli ses çal
        if enableHapticFeedback {
            SoundManager.shared.playNavigationSound()
        } else {
            // Titreşim kapalıysa sadece ses çal
            SoundManager.shared.playNavigationSoundOnly()
        }
    }
    
    // GPU hızlandırmayı aç/kapat - daima açık kalacak
    func toggleGPUAcceleration() {
        // GPU hızlandırma her zaman açık - değişiklik yapma
        enableGPUAcceleration = true
        
        // Titreşim açıksa titreşimli ses çal
        if enableHapticFeedback {
            SoundManager.shared.playNavigationSound()
        } else {
            // Titreşim kapalıysa sadece ses çal
            SoundManager.shared.playNavigationSoundOnly()
        }
        
        // Değişiklik bildir
        NotificationCenter.default.post(name: NSNotification.Name("GPUAccelerationChanged"), object: nil)
    }
    
    // Güç tasarrufu seviyesini manuel olarak ayarla
    func setPowerSavingLevel(_ level: PowerSavingLevel) {
        powerSavingLevel = level
        powerSavingMode = (level != .off)
        
        // Manuel değişiklik yapıldığında otomatik modu sıfırla
        if powerSavingMode {
            isAutoPowerSavingActive = false
        }
        
        // Titreşim açıksa titreşimli ses çal
        if enableHapticFeedback {
            SoundManager.shared.playNavigationSound()
        } else {
            // Titreşim kapalıysa sadece ses çal
            SoundManager.shared.playNavigationSoundOnly()
        }
    }
    
    // Güç tasarrufu durumunu kontrol et
    var isPowerSavingEnabled: Bool {
        get { 
            // Yüksek performans modunda her zaman false döndür
            return highPerformanceMode ? false : powerSavingMode 
        }
        set { powerSavingMode = newValue }
    }
    
    // Otomatik güç tasarrufu durumunu kontrol et
    var isAutoPowerSavingEnabled: Bool {
        get { return autoPowerSaving }
        set { autoPowerSaving = newValue }
    }
    
    // GPU hızlandırma durumunu kontrol et - her zaman true döndürür
    var isGPUAccelerationEnabled: Bool {
        get { return true }
        set { /* her zaman açık kalacak - görmezden gel */ }
    }
    
    // Animasyon hızı faktörü - seviyeye göre
    var animationSpeedFactor: Double {
        if highPerformanceMode {
            return 1.2  // Yüksek performans modunda daha hızlı animasyonlar
        }
        
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.7 // 0.8'den daha düşük faktöre değiştirildi
        case .medium: return 0.5 // 0.6'dan daha düşük faktöre değiştirildi
        case .high: return 0.3 // 0.4'ten daha düşük faktöre değiştirildi
        case .off: return 1.0
        }
    }
    
    // Animasyon karmaşıklığı faktörü - seviyeye göre
    var animationComplexityFactor: Double {
        if highPerformanceMode {
            return 1.2  // Yüksek performans modunda daha karmaşık animasyonlar
        }
        
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.6 // 0.7'den daha düşük faktöre değiştirildi
        case .medium: return 0.4 // 0.5'ten daha düşük faktöre değiştirildi
        case .high: return 0.1 // 0.2'den daha düşük faktöre değiştirildi
        case .off: return 1.0
        }
    }
    
    // Görsel efekt kalitesi faktörü - seviyeye göre
    var visualEffectQualityFactor: Double {
        if highPerformanceMode {
            return 1.2  // Yüksek performans modunda daha yüksek kaliteli efektler
        }
        
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.6 // 0.8'den daha düşük faktöre değiştirildi
        case .medium: return 0.3 // 0.5'ten daha düşük faktöre değiştirildi
        case .high: return 0.1 // 0.3'ten daha düşük faktöre değiştirildi
        case .off: return 1.0
        }
    }
    
    // Arka plan işlemlerini optimize et
    var shouldOptimizeBackgroundTasks: Bool {
        return isPowerSavingEnabled && (powerSavingLevel == .medium || powerSavingLevel == .high)
    }
    
    // Yüksek kaliteli görseller kullan - artık GPU hızlandırma her zaman açık
    var shouldUseHighQualityRendering: Bool {
        // Her durumda yüksek kalite rendering kullan
        return true
    }
    
    // Kullanıcı etkileşimlerini sınırlandır
    func throttleInteractions() -> Bool {
        // Devre dışı bırakıldı - her zaman false döndür
        return false
    }
    
    // Etkileşim sınırlanıyor mu kontrol et
    var isUserInteractionThrottled: Bool {
        return isThrottling
    }
    
    // GPU hızlandırması kontrolü - her zaman true döndürür
    var useMetalRendering: Bool {
        // Her zaman Metal kullan
        return true
    }
}

// View uzantısı - güç tasarrufu moduna göre animasyon ayarları
extension View {
    func powerSavingAwareAnimation<Value: Equatable>(
        _ animation: Animation? = .default,
        value: Value
    ) -> some View {
        let powerManager = PowerSavingManager.shared
        let isPowerSaving = powerManager.isPowerSavingEnabled
        
        if !isPowerSaving {
            return self.animation(animation, value: value)
        }
        
        // Güç tasarrufu seviyesine göre animasyon hızını ayarla
        return self.animation(
            animation?.speed(powerManager.animationSpeedFactor),
            value: value
        )
    }
    
    // Güç tasarrufu moduna göre görsel efektleri ayarla
    func powerSavingAwareEffect(
        isEnabled: Bool = true,
        shadowRadius: CGFloat = 3,
        shadowOpacity: Double = 0.1
    ) -> some View {
        let powerManager = PowerSavingManager.shared
        let isPowerSaving = powerManager.isPowerSavingEnabled
        
        if !isEnabled || isPowerSaving && powerManager.powerSavingLevel != .low {
            // Gölge yok - maksimum performans
            return AnyView(self)
        } else if isPowerSaving && powerManager.powerSavingLevel == .low {
            // Düşük kalite gölge
            return AnyView(
                self.shadow(color: Color.black.opacity(shadowOpacity/2), radius: shadowRadius/2, x: 0, y: 1)
            )
        } else {
            // Tam kalite gölge
            return AnyView(
                self.shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 1)
            )
        }
    }
    
    // Render kalitesi ve yöntemi - Her zaman GPU kullanır
    func powerSavingAwareRendering(isEnabled: Bool = true) -> some View {
        // Her zaman yüksek kalite render - drawingGroup ile Metal hızlandırması
        return AnyView(self.drawingGroup(opaque: true, colorMode: .linear))
    }
    
    // GPU hızlandırması her zaman açık - standart kullanım için
    func gpuAcceleratedView() -> some View {
        return self.drawingGroup(opaque: true, colorMode: .linear)
    }
}
