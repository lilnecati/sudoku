import UIKit
import Firebase
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    weak var themeManager: ThemeManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase'i burada yapılandır
        FirebaseApp.configure()
        logSuccess("Firebase AppDelegate içinde yapılandırıldı.")

        logInfo("AppDelegate: application didFinishLaunchingWithOptions")
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: Notification.Name("ThemeChanged"), object: nil)
        
        // PersistenceController'daki Firebase özelliklerini etkinleştir
        PersistenceController.shared.activateFirebaseFeatures()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions are being discarded while the application is not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Sudoku")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    @objc func themeChanged() {
        // Değişiklik: themeManager'ı oluşturmak yerine sadece varlığını kontrol et
        guard themeManager != nil else { return }
        logInfo("AppDelegate: ThemeChanged notification received. Applying new theme.")
        DispatchQueue.main.async {
             // updateAppearance metodu SudokuApp içindeydi, burada tekrar tanımlamaya gerek yok.
             // Gerekirse ThemeManager üzerinden çağrılabilir veya SudokuApp içindeki
             // AppDelegate referansı aracılığıyla tetiklenebilir.
             // Şimdilik burayı boş bırakalım veya sadece log yazalım.
             logInfo("AppDelegate themeChanged: Appearance update logic needs review.")
             // self.updateAppearance(themeManager: themeManager) // Bu metod burada tanımlı değil
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logInfo("AppDelegate: applicationWillTerminate")
        PersistenceController.shared.save() // CoreData kaydetme işlemi
    }
} 