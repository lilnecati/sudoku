import SwiftUI
import Combine

class PowerSavingManager: ObservableObject {
    // Singleton örneği
    static let shared = PowerSavingManager()
    
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
        
        // Dokunsal geribildirim
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Güç tasarrufu seviyesini manuel olarak ayarla
    func setPowerSavingLevel(_ level: PowerSavingLevel) {
        powerSavingLevel = level
        powerSavingMode = (level != .off)
        
        // Manuel değişiklik yapıldığında otomatik modu sıfırla
        if powerSavingMode {
            isAutoPowerSavingActive = false
        }
    }
    
    // Güç tasarrufu durumunu kontrol et
    var isPowerSavingEnabled: Bool {
        get { return powerSavingMode }
        set { powerSavingMode = newValue }
    }
    
    // Otomatik güç tasarrufu durumunu kontrol et
    var isAutoPowerSavingEnabled: Bool {
        get { return autoPowerSaving }
        set { autoPowerSaving = newValue }
    }
    
    // Animasyon hızı faktörü - seviyeye göre
    var animationSpeedFactor: Double {
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.8
        case .medium: return 0.6
        case .high: return 0.4
        case .off: return 1.0
        }
    }
    
    // Animasyon karmaşıklığı faktörü - seviyeye göre
    var animationComplexityFactor: Double {
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.7
        case .medium: return 0.5
        case .high: return 0.2
        case .off: return 1.0
        }
    }
    
    // Görsel efekt kalitesi faktörü - seviyeye göre
    var visualEffectQualityFactor: Double {
        if !isPowerSavingEnabled {
            return 1.0
        }
        
        switch powerSavingLevel {
        case .low: return 0.8
        case .medium: return 0.5
        case .high: return 0.3
        case .off: return 1.0
        }
    }
    
    // Arka plan işlemlerini optimize et
    var shouldOptimizeBackgroundTasks: Bool {
        return isPowerSavingEnabled && (powerSavingLevel == .medium || powerSavingLevel == .high)
    }
    
    // Yüksek kaliteli görseller kullan
    var shouldUseHighQualityRendering: Bool {
        return !isPowerSavingEnabled || powerSavingLevel == .low
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
    
    // Güç tasarrufu moduna göre render kalitesi ve yöntemi
    func powerSavingAwareRendering(isEnabled: Bool = true) -> some View {
        let powerManager = PowerSavingManager.shared
        
        if !isEnabled || !powerManager.isPowerSavingEnabled || powerManager.powerSavingLevel == .low {
            // Yüksek kalite render - drawingGroup ile Metal hızlandırması
            return AnyView(self.drawingGroup())
        } else if powerManager.powerSavingLevel == .medium {
            // Orta kalite render - basit optimizasyon
            return AnyView(self)
        } else {
            // Düşük kalite render - animasyonsuz basit görünüm
            return AnyView(self)
        }
    }
}
