import Foundation

/// Merkezi loglama sistemi
class LogManager {
    static let shared = LogManager()
    
    enum LogLevel: Int {
        case none = 0    // hiç log gösterme
        case error = 1   //  hatalar
        case warning = 2 // hatalar ve uyarılar
        case info = 3    // bilgi mesajları
        case debug = 4   // geliştirme aşamasında kullanılan detaylı loglar
        case verbose = 5 // wn detaylı loglar
    }
    
    private var currentLogLevel: LogLevel = .info
    
    private var isProduction: Bool = false
    
    private init() {
        #if DEBUG
        isProduction = false
        currentLogLevel = .debug
        #else
        isProduction = true
        currentLogLevel = .warning  // Production modunda sadece warning ve error logları göster
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
        guard level.rawValue <= currentLogLevel.rawValue else { return }
        
        // Production modunda sadece info ve altı logları tutuyoruz
        if isProduction && level.rawValue > currentLogLevel.rawValue {
            return
        }
        
        let fileName = (file as NSString).lastPathComponent
        
        // Daha kısa log mesajları için sadece dosya adı ve satır numarasını göster
        let logMessage = "[\(fileName):\(line)] \(message)"
        
        print(logMessage)
    }
}

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
