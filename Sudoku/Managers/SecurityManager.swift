import Foundation
import CommonCrypto

/**
 * SecurityManager
 *
 * Uygulama genelinde güvenlik işlemlerini yönetir:
 * - Şifre hashlemesi
 * - Salt oluşturma ve ekleme
 * - Şifre doğrulama
 */
class SecurityManager {
    static let shared = SecurityManager()
    
    private init() {}
    
    /// Güvenli bir salt (tuz) oluşturur
    func generateSalt() -> String {
        let length = 32
        var salt = [UInt8](repeating: 0, count: length)
        
        // Rastgele güvenli bytes oluştur
        _ = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        
        // Base64 formatında string'e çevir
        return Data(salt).base64EncodedString()
    }
    
    /// Şifreyi hash'ler ve salt ekler
    func hashPassword(_ password: String, salt: String) -> String {
        let combinedString = password + salt
        
        // String'i data'ya çevir
        guard let combinedData = combinedString.data(using: .utf8) else {
            logError("String veri dönüşümü başarısız")
            return ""
        }
        
        // Hash'leme işlemi
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        combinedData.withUnsafeBytes { messageBytes in
            _ = CC_SHA256(messageBytes.baseAddress, CC_LONG(combinedData.count), &digest)
        }
        
        // Hash'i hexadecimal string formatına çevir
        let hashedData = Data(digest)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Şifreyi doğrular
    func verifyPassword(_ password: String, against hashedPassword: String, salt: String) -> Bool {
        let newHashedPassword = hashPassword(password, salt: salt)
        return newHashedPassword == hashedPassword
    }
    
    /// Güçlü şifre kontrolü yapar
    func isStrongPassword(_ password: String) -> (isStrong: Bool, message: String) {
        // Minimum 8 karakter
        if password.count < 8 {
            return (false, "Şifre en az 8 karakter olmalıdır.")
        }
        
        // En az bir büyük harf
        let uppercaseLetterRegex = ".*[A-Z]+.*"
        if !NSPredicate(format: "SELF MATCHES %@", uppercaseLetterRegex).evaluate(with: password) {
            return (false, "Şifre en az bir büyük harf içermelidir.")
        }
        
        // En az bir küçük harf
        let lowercaseLetterRegex = ".*[a-z]+.*"
        if !NSPredicate(format: "SELF MATCHES %@", lowercaseLetterRegex).evaluate(with: password) {
            return (false, "Şifre en az bir küçük harf içermelidir.")
        }
        
        // En az bir rakam
        let digitRegex = ".*[0-9]+.*"
        if !NSPredicate(format: "SELF MATCHES %@", digitRegex).evaluate(with: password) {
            return (false, "Şifre en az bir rakam içermelidir.")
        }
        
        // En az bir özel karakter
        let specialCharRegex = ".*[!@#$%^&*()\\-_=+{}|?>.<]+.*"
        if !NSPredicate(format: "SELF MATCHES %@", specialCharRegex).evaluate(with: password) {
            return (false, "Şifre en az bir özel karakter içermelidir.")
        }
        
        return (true, "Şifre güçlü.")
    }
    
    /// Kullanıcı adı geçerliliğini kontrol eder
    func isValidUsername(_ username: String) -> (isValid: Bool, message: String) {
        // En az 4 karakter
        if username.count < 4 {
            return (false, "Kullanıcı adı en az 4 karakter olmalıdır.")
        }
        
        // Alfanumerik ve alt çizgi dışında karakter olmamalı
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        if !NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username) {
            return (false, "Kullanıcı adı sadece harf, rakam ve alt çizgi içermelidir.")
        }
        
        return (true, "Kullanıcı adı geçerli.")
    }
    
    /// E-posta geçerliliğini kontrol eder
    func isValidEmail(_ email: String) -> (isValid: Bool, message: String) {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let isValid = NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
        
        return (isValid, isValid ? "E-posta geçerli." : "Geçerli bir e-posta adresi girin.")
    }
} 