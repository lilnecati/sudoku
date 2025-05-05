import Foundation
import Combine
import FirebaseAuth // Firebase Auth kütüphanesini ekleyelim

class SessionManager: ObservableObject {
    
    // Paylaşılan (singleton) örnek
    static let shared = SessionManager()
    
    // @Published değişkenler SwiftUI görünümlerinin otomatik güncellenmesini sağlar
    @Published var currentUser: FirebaseAuth.User? = nil
    @Published var isLoggedIn: Bool = false
    
    // Oturum durumu değişikliklerini yayınlayan publisher'lar
    let sessionDidBecomeActivePublisher = PassthroughSubject<Void, Never>()
    let sessionDidBecomeInactivePublisher = PassthroughSubject<Void, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // currentUser değişkenindeki değişiklikleri dinle
        $currentUser
            .map { $0 != nil } // isLoggedIn durumunu hesapla
            .removeDuplicates() // Sadece durum değiştiğinde devam et
            .sink { [weak self] loggedInStatus in
                guard let self = self else { return }
                
                // Önce isLoggedIn @Published değişkenini güncelle (UI tepkisi için)
                self.isLoggedIn = loggedInStatus
                logInfo("SessionManager: isLoggedIn changed to \(loggedInStatus)")
                
                // Sonra ilgili publisher'ı tetikle
                if loggedInStatus {
                    logInfo("SessionManager: Triggering sessionDidBecomeActivePublisher")
                    self.sessionDidBecomeActivePublisher.send()
                } else {
                    logInfo("SessionManager: Triggering sessionDidBecomeInactivePublisher")
                    self.sessionDidBecomeInactivePublisher.send()
                }
            }
            .store(in: &cancellables)
            
        logInfo("SessionManager initialized.")
        // Başlangıçta mevcut oturum durumunu kontrol et (isteğe bağlı ama iyi pratik)
        // Not: Bu kontrol PersistenceController'daki listener ile çakışabilir.
        // Şimdilik PersistenceController'daki listener'a güvenelim.
        // self.currentUser = Auth.auth().currentUser 
    }
    
    // Bu metod PersistenceController'daki listener tarafından çağrılacak
    func updateUserState(_ firebaseUser: FirebaseAuth.User?) {
         // Gelen kullanıcı bilgisini doğrudan currentUser'a ata.
         // Combine pipeline'ı isLoggedIn'i otomatik olarak güncelleyecektir.
        DispatchQueue.main.async { // @Published değişkenler ana thread'de güncellenmeli
             self.currentUser = firebaseUser
             logInfo("SessionManager state updated. User is \(firebaseUser == nil ? "nil" : "NOT nil"). isLoggedIn = \(self.isLoggedIn)")
        }
    }
}

// Kaldırıldı: logInfo fonksiyonu muhtemelen projede zaten tanımlı.
/*
// Helper log fonksiyonu (eğer projenizde merkezi bir loglama sistemi yoksa)
// Eğer varsa, projenizdeki loglama fonksiyonunu kullanın.
#if DEBUG
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("ℹ️ [\(fileName):\(line)] \(function) - \(message)")
}
#else
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    // Release modunda loglama yapma
}
#endif 
*/ 