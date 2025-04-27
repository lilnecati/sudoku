import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Sahne ilk kez oluşturulduğunda çağrılır
        guard let _ = (scene as? UIWindowScene) else { return }
        
        // İlk başlatmada, yüksek performans modunu devre dışı bırak
        // ve Metal hızlandırmayı etkinleştir
        PowerSavingManager.shared.highPerformanceMode = false
        PowerSavingManager.shared.enableGPUAcceleration = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Sahne bağlantısı kesildiğinde çağrılır
        // Bu genellikle sistem tarafından kaynakları geri kazanmak için yapılır
        // Sahne daha sonra yeniden bağlanabilir veya bağlanmayabilir
        
        // Ekran kararması yönetimi SudokuApp'a devredildi
        
        // Arka plan görevlerini duraklat
        NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundTasks"), object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Sahne aktif duruma geçtiğinde çağrılır
        
        // ÇOK ÖNEMLİ: Ekran kararması yönetimi SudokuApp'a devredildi
        // CPU kullanımını azaltmak için Metal hızlandırmayı etkinleştir
        DispatchQueue.main.async {
            // GPU hızlandırmayı etkinleştir - CPU kullanımını düşürür
            PowerSavingManager.shared.enableGPUAcceleration = true
            
            // Yüksek performans modunu kapat ve güç tasarrufu modunu etkinleştir
            PowerSavingManager.shared.highPerformanceMode = false
            
            if !PowerSavingManager.shared.isPowerSavingEnabled {
                PowerSavingManager.shared.powerSavingMode = true
                PowerSavingManager.shared.setPowerSavingLevel(.high)
            }
            
            // GPU hızlandırma değişikliğini bildir
            NotificationCenter.default.post(name: NSNotification.Name("GPUAccelerationChanged"), object: nil)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Sahne aktif olmaktan çıkacağı zaman çağrılır
        // Bu, geçici kesintiler nedeniyle olabilir (örneğin, gelen telefon çağrısı)
        
        // ÇOK ÖNEMLİ: Ekran kararması yönetimi SudokuApp'a devredildi
        // Uygulamada görünürlükte yoksa, yüksek CPU kullanımını önlemek için ek önlemler al
        DispatchQueue.main.async {
            // Maksimum güç tasarrufunu zorla
            PowerSavingManager.shared.highPerformanceMode = false
            PowerSavingManager.shared.powerSavingMode = true
            PowerSavingManager.shared.setPowerSavingLevel(.high)
            
            // GPU hızlandırmayı aktif tut - CPU yükünü azaltır
            PowerSavingManager.shared.enableGPUAcceleration = true
            
            // CPU kullanımını azaltmak için zamanlanmış işlemleri durdur
            NotificationCenter.default.post(name: NSNotification.Name("PauseBackgroundTasks"), object: nil)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Sahne ön plana geçecekken çağrılır
        // Örneğin, uygulamaya geri dönerken
        
        // ÇOK ÖNEMLİ: Ekran kararması yönetimi SudokuApp'a devredildi
        // Ön plana geçerken GPU hızlandırmayı etkinleştir - CPU kullanımını düşürür
        DispatchQueue.main.async {
            PowerSavingManager.shared.enableGPUAcceleration = true
            
            // GPU hızlandırma değişikliğini bildir
            NotificationCenter.default.post(name: NSNotification.Name("GPUAccelerationChanged"), object: nil)
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Sahne arka plana geçtiğinde çağrılır
        // Kullanıcı uygulamayı kapattığında
        
        // ÇOK ÖNEMLİ: Ekran kararmasını ZORLA ETKİNLEŞTİRME (GameView yönetecek)
        // logInfo("SceneDelegate sceneDidEnterBackground - Ekran kararması ZORLA ETKİNLEŞTİRİLDİ (ekran kararabilir)")
        
        // Arka planda kalıcı depolama ve CPU kullanımını azalt
        DispatchQueue.main.async {
            // Tüm işlemleri en düşük seviyeye indir
            PowerSavingManager.shared.highPerformanceMode = false
            PowerSavingManager.shared.powerSavingMode = true
            PowerSavingManager.shared.setPowerSavingLevel(.high)
            
            // GPU hızlandırmayı AÇIK tut - geçişlerde daha akıcı deneyim için
            PowerSavingManager.shared.enableGPUAcceleration = true
            
            // Tüm arkaplan işlerini durdur
            NotificationCenter.default.post(name: NSNotification.Name("StopAllBackgroundTasks"), object: nil)
            
            // Oyun durumunu kaydet
            NotificationCenter.default.post(name: NSNotification.Name("SaveGameState"), object: nil)
        }
    }
}