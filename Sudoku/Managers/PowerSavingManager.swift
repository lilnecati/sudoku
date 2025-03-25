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
    
    // Düşük pil eşiği
    private let lowBatteryThreshold: Float = 0.2 // %20
    
    // Otomatik güç tasarrufu durumu
    @Published private(set) var isAutoPowerSavingActive: Bool = false
    
    // Cancellable
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // Otomatik güç tasarrufu kontrolü
    private func checkAutoPowerSaving() {
        if autoPowerSaving && !isCharging && batteryLevel <= lowBatteryThreshold {
            // Pil seviyesi düşük ve şarj edilmiyor, otomatik güç tasarrufu etkinleştir
            if !powerSavingMode {
                powerSavingMode = true
                isAutoPowerSavingActive = true
            }
        } else if isAutoPowerSavingActive && (isCharging || batteryLevel > lowBatteryThreshold) {
            // Şarj ediliyor veya pil seviyesi yeterli, otomatik güç tasarrufunu devre dışı bırak
            if powerSavingMode {
                powerSavingMode = false
                isAutoPowerSavingActive = false
            }
        }
    }
    
    // Güç tasarrufu modunu manuel olarak değiştir
    func togglePowerSavingMode() {
        powerSavingMode.toggle()
        
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
    
    // Animasyon hızı faktörü
    var animationSpeedFactor: Double {
        return isPowerSavingEnabled ? 0.5 : 1.0
    }
    
    // Animasyon karmaşıklığı faktörü
    var animationComplexityFactor: Double {
        return isPowerSavingEnabled ? 0.3 : 1.0
    }
    
    // Görsel efekt kalitesi faktörü
    var visualEffectQualityFactor: Double {
        return isPowerSavingEnabled ? 0.5 : 1.0
    }
}

// View uzantısı - güç tasarrufu moduna göre animasyon ayarları
extension View {
    func powerSavingAwareAnimation<Value: Equatable>(
        _ animation: Animation? = .default,
        value: Value
    ) -> some View {
        let isPowerSaving = PowerSavingManager.shared.isPowerSavingEnabled
        
        return self.animation(
            isPowerSaving ? animation?.speed(PowerSavingManager.shared.animationSpeedFactor) : animation,
            value: value
        )
    }
    
    func powerSavingAwareEffect(
        isEnabled: Bool = true
    ) -> some View {
        let isPowerSaving = PowerSavingManager.shared.isPowerSavingEnabled
        
        if isPowerSaving || !isEnabled {
            return AnyView(self)
        } else {
            return AnyView(
                self.shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            )
        }
    }
}
