import Foundation

/// Merkezi loglama sistemi
class LogManager {
    static let shared = LogManager()
    
    // Log seviyelerini tanımlayalım
    enum LogLevel: Int {
        case none = 0    // Hiç log gösterme
        case error = 1   // Sadece hatalar
        case warning = 2 // Hatalar ve uyarılar
        case info = 3    // Bilgi mesajları
        case debug = 4   // Geliştirme aşamasında kullanılan detaylı loglar
        case verbose = 5 // En detaylı loglar
    }
    
    // Geçerli log seviyesi - varsayılan olarak info
    private var currentLogLevel: LogLevel = .info
    
    // Üretim modunda mı çalışıyoruz?
    private var isProduction: Bool = false
    
    private init() {
        // Debug modunda mı çalışıyoruz?
        #if DEBUG
        isProduction = false
        currentLogLevel = .debug // Debug modunda daha detaylı loglar
        #else
        isProduction = true
        currentLogLevel = .info  // Üretim modunda sadece önemli loglar
        #endif
    }
    
    /// Log seviyesini ayarla
    func setLogLevel(_ level: LogLevel) {
        currentLogLevel = level
    }
    
    /// Hata logu
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: "❌ \(message)", file: file, function: function, line: line)
    }
    
    /// Uyarı logu
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: "⚠️ \(message)", file: file, function: function, line: line)
    }
    
    /// Bilgi logu
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: "ℹ️ \(message)", file: file, function: function, line: line)
    }
    
    /// Debug logu
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: "🔍 \(message)", file: file, function: function, line: line)
    }
    
    /// Detaylı log
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, message: "📝 \(message)", file: file, function: function, line: line)
    }
    
    /// Başarı logu
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: "✅ \(message)", file: file, function: function, line: line)
    }
    
    /// Ana log fonksiyonu
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        // Eğer geçerli log seviyesi, gelen log seviyesinden düşükse, logu gösterme
        guard level.rawValue <= currentLogLevel.rawValue else { return }
        
        // Üretim modunda sadece error ve info loglarını göster
        if isProduction && level.rawValue > LogLevel.info.rawValue {
            return
        }
        
        // Dosya adını al
        let fileName = (file as NSString).lastPathComponent
        
        // Log mesajını oluştur
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        
        // Konsola yazdır
        print(logMessage)
        
        // Burada isterseniz dosyaya yazma, uzak sunucuya gönderme gibi işlemler ekleyebilirsiniz
    }
}

// Kolay erişim için global fonksiyonlar
func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.error(message, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.warning(message, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.info(message, file: file, function: function, line: line)
}

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.debug(message, file: file, function: function, line: line)
}

func logVerbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.verbose(message, file: file, function: function, line: line)
}

func logSuccess(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    LogManager.shared.success(message, file: file, function: function, line: line)
}
