import SwiftUI
import CoreData
import PhotosUI // Fotoğraf seçimi için eklendi

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    // Klavye durumunu takip edecek state
    @State private var keyboardIsVisible = false
    
    // Focus states
    @FocusState private var focusName: Bool
    @FocusState private var focusEmail: Bool
    @FocusState private var focusCurrentPassword: Bool
    @FocusState private var focusNewPassword: Bool
    @FocusState private var focusConfirmPassword: Bool
    
    // Yeni eklenen state değişkenleri
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0.0
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    
    // Yeniden kimlik doğrulama için
    @State private var showReauthDialog = false
    
    @State private var showPasswordChange = false
    
    // Cloudinary API bilgileri
    private let cloudName = "dn5ciuoia" // Cloudinary hesabınızdan alındı
    private let uploadPreset = "sudoku_app" // İmzasız yüklemeler için özel preset
    
    // Mevcut kullanıcı bilgilerini yükle
    private var currentUser: User? {
        return PersistenceController.shared.getCurrentUser()
    }
    
    // Klavyeyi kapat
    private func dismissKeyboard() {
        focusName = false
        focusEmail = false
        focusCurrentPassword = false
        focusNewPassword = false
        focusConfirmPassword = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Arka plan - performans için optimize edildi
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
                .overlay(
            GridBackgroundView()
                .ignoresSafeArea()
                        .opacity(0.5) // Arka planı hafifletelim
                )
            
            ScrollView {
                VStack(spacing: 25) {
                    // Profil Başlığı
                    profileHeader
                    
                    // Yükleme göstergesi
                    if isUploadingImage {
                        VStack {
                            ProgressView("Fotoğraf yükleniyor...")
                            Text("\(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Profil düzenleme formu
                    profileForm
                    
                    // Şifre değiştirme butonları
                    passwordChangeSection
                    
                    // Hesap silme butonu
                    deleteAccountButton
                    
                    Spacer()
                }
                .padding()
                .onAppear {
                    // Klavyeyi takip et
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                        keyboardIsVisible = true
                    }
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                        keyboardIsVisible = false
                    }
                    
                    loadUserData()
            }
            }
            .scrollDismissesKeyboard(.immediately) // Anında klavyeyi kapat
            .hideKeyboardWhenTappedOutside() // Metin alanı dışına dokunulduğunda klavyeyi kapat
        }
        .navigationTitle("Profil Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Kaydet") {
                    saveProfile()
                }
                .disabled(isLoading || isUploadingImage)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("Tamam")) {
                    // Alert kapatıldığında yapılacak işlemler
                    if alertTitle == "Başarılı" {
                        // Başarı mesajı gösterildikten sonra bildirimi düzgün kapat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // İşlemler tamamlandıktan sonra gerekirse ek işlemler yapılabilir
                        }
                    }
                }
            )
        }
        .actionSheet(isPresented: $showDeleteConfirmation) {
            ActionSheet(
                title: Text("Hesabı Sil"),
                message: Text("Bu işlem geri alınamaz. Tüm verileriniz silinecektir."),
                buttons: [
                    .destructive(Text("Hesabı Sil")) {
                        // Yeniden kimlik doğrulama diyaloğunu göster
                        showReauthDialog = true
                    },
                    .cancel()
                ]
            )
        }
        // Yeniden kimlik doğrulama diyaloğu
        .alert(isPresented: $showReauthDialog) {
            Alert(
                title: Text("Hesabı Silme Onayı"),
                message: Text("Bu işlem geri alınamaz. Tüm verileriniz silinecektir."),
                primaryButton: .destructive(Text("Hesabı Sil")) {
                    // Hesap silme işlemi
                    isLoading = true
                    alertTitle = "Hesap Siliniyor"
                    alertMessage = "Hesabınız siliniyor, lütfen bekleyin..."
                    showAlert = true
                    
                    PersistenceController.shared.deleteUserAccount { success, error in
                        DispatchQueue.main.async {
                            isLoading = false
                            
                            if success {
                                // Hesap başarıyla silindi
                                alertTitle = "Başarılı"
                                alertMessage = "Hesabınız başarıyla silindi."
                                showAlert = true
                                
                                // Ana menü ekranına dön
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                            } else {
                                // Hesap silme işlemi başarısız oldu
                                alertTitle = "Hata"
                                alertMessage = "Hesap silme işlemi başarısız oldu: \(error?.localizedDescription ?? "Bilinmeyen hata")"
                                showAlert = true
                            }
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, didSelectImage: { image in
                if let image = image {
                    // Resim seçildiğinde Cloudinary'ye yükle
                    uploadImageToCloudinary(image)
                }
            })
        }
    }
    
    // Profil başlık kısmı
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Profil resmi
            ZStack {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Text(String(name.prefix(1)))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                // Fotoğraf değiştirme butonu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingImagePicker = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(isUploadingImage)
                    }
                }
                .frame(width: 100, height: 100)
            }
            
            // Kullanıcı adı
            Text(username)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    // Profil düzenleme formu
    private var profileForm: some View {
        VStack(spacing: 20) {
            // Ad Soyad
            VStack(alignment: .leading, spacing: 8) {
                Text("Ad Soyad")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Adınızı ve soyadınızı girin", text: $name)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .focused($focusName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusEmail = true
                    }
            }
            
            // E-posta
            VStack(alignment: .leading, spacing: 8) {
                Text("E-posta")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("E-posta adresinizi girin", text: $email)
                    .padding()
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .focused($focusEmail)
                    .submitLabel(.done)
                    .onSubmit {
                        dismissKeyboard()
                    }
            }
            
            // Kullanıcı Adı
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Kullanıcı Adı")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("(Değiştirilemez)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                HStack {
                    // Kullanıcı adını doğru şekilde göster
                    let displayUsername = username.isEmpty ? "Henüz kullanıcı adı oluşturulmamış" : username
                    Text(displayUsername)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(username.isEmpty ? .secondary : .primary)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    // Şifre değiştirme bölümü
    private var passwordChangeSection: some View {
        VStack(spacing: 20) {
            // Şifre değiştir butonu
            Button(action: {
                showPasswordChange.toggle()
                // Şifre değiştirme formunu açarken klavyeyi kapat
                dismissKeyboard()
            }) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                    
                    Text("Şifre Değiştir")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: showPasswordChange ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            
            // Şifre değiştirme formu - koşullu olarak göster
            if showPasswordChange {
                VStack(spacing: 15) {
                    // Mevcut şifre
                    SecureField("Mevcut Şifre", text: $currentPassword)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .focused($focusCurrentPassword)
                        .submitLabel(.next)
                        .onSubmit {
                            focusNewPassword = true
                        }
                    
                    // Yeni şifre
                    SecureField("Yeni Şifre", text: $newPassword)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .focused($focusNewPassword)
                        .submitLabel(.next)
                        .onSubmit {
                            focusConfirmPassword = true
                        }
                    
                    // Yeni şifre onay
                    SecureField("Yeni Şifre (Tekrar)", text: $confirmPassword)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .focused($focusConfirmPassword)
                        .submitLabel(.done)
                        .onSubmit {
                            dismissKeyboard()
                            if isPasswordChangeValid {
                                changePassword()
                            }
                        }
                    
                    // Şifre gücü bilgisi
                    if !newPassword.isEmpty {
                        let passwordCheck = SecurityManager.shared.isStrongPassword(newPassword)
                        Text(passwordCheck.message)
                            .font(.caption)
                            .foregroundColor(passwordCheck.isStrong ? .green : .red)
                    }
                    
                    // Şifre eşleşme kontrolü
                    if !confirmPassword.isEmpty {
                        Text(newPassword == confirmPassword ? "Şifreler eşleşiyor" : "Şifreler eşleşmiyor")
                            .font(.caption)
                            .foregroundColor(newPassword == confirmPassword ? .green : .red)
                    }
                    
                    // Şifre değiştir butonu
                    Button(action: changePassword) {
                        Text("Şifre Değiştir")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isPasswordChangeValid ? Color.blue : Color.gray)
                            )
                    }
                    .disabled(!isPasswordChangeValid)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clear)
                )
            }
        }
        .padding(.vertical, 10)
    }
    
    // Hesap silme butonu
    private var deleteAccountButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                
                Text("Hesabı Sil")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.red, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.red.opacity(0.1) : Color.red.opacity(0.05))
                    )
            )
        }
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
    
    // Kullanıcı verilerini yükle
    private func loadUserData() {
        guard let user = currentUser else { return }
        
        name = user.name ?? ""
        email = user.email ?? ""
        username = user.username ?? ""
        
        // Debug bilgisi
        logDebug("ProfileEditView - Kullanıcı adı: \(username)")
        logDebug("ProfileEditView - E-posta: \(email)")
        
        // Profil resmi varsa yükle
        if let imageData = user.profileImage, let image = UIImage(data: imageData) {
            selectedImage = image
        } else if let photoURL = user.photoURL {
            // Cloudinary'den profil resmini yükle
            loadImageFromURL(urlString: photoURL)
        }
    }
    
    // Şifre değiştirme geçerlilik kontrolü
    private var isPasswordChangeValid: Bool {
        // Mevcut şifre girilmiş olmalı
        guard !currentPassword.isEmpty else { return false }
        
        // Yeni şifre gereksinimlerini kontrol et
        let passwordCheck = SecurityManager.shared.isStrongPassword(newPassword)
        guard passwordCheck.isStrong else { return false }
        
        // Şifre onayı eşleşmeli
        guard newPassword == confirmPassword else { return false }
        
        return true
    }
    
    // Profil değişikliklerini kaydet
    private func saveProfile() {
        isLoading = true
        
        // E-posta geçerliliğini kontrol et
        let emailCheck = SecurityManager.shared.isValidEmail(email)
        if !emailCheck.isValid {
            alertTitle = "Hata"
            alertMessage = emailCheck.message
            showAlert = true
            isLoading = false
            return
        }
        
        // CoreData işlemleri
        guard let user = currentUser else {
            isLoading = false
            return
        }
        
        let context = PersistenceController.shared.container.viewContext
        
        // Temel bilgileri kaydet
        user.name = name
        user.email = email
        
        // Profil resmi varsa kaydet
        if let selectedImage = selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.7) {
            user.profileImage = imageData
        }
        
        do {
            try context.save()
            alertTitle = "Başarılı"
            alertMessage = "Profil bilgileriniz güncellendi."
            showAlert = true
            isLoading = false
        } catch {
            alertTitle = "Hata"
            alertMessage = "Profil güncellenemedi: \(error.localizedDescription)"
            showAlert = true
            isLoading = false
        }
    }
    
    // Şifre değiştir
    private func changePassword() {
        isLoading = true
        
        guard let user = currentUser,
              let storedPassword = user.password,
              let salt = user.passwordSalt else {
            isLoading = false
            return
        }
        
        // Mevcut şifre doğrulama
        if !SecurityManager.shared.verifyPassword(currentPassword, against: storedPassword, salt: salt) {
            alertTitle = "Hata"
            alertMessage = "Mevcut şifreniz yanlış."
            showAlert = true
            isLoading = false
            return
        }
        
        // Yeni şifre güvenlik kontrolü
        let passwordCheck = SecurityManager.shared.isStrongPassword(newPassword)
        if !passwordCheck.isStrong {
            alertTitle = "Hata"
            alertMessage = passwordCheck.message
            showAlert = true
            isLoading = false
            return
        }
        
        // Şifre eşleşme kontrolü
        if newPassword != confirmPassword {
            alertTitle = "Hata"
            alertMessage = "Yeni şifreler eşleşmiyor."
            showAlert = true
            isLoading = false
            return
        }
        
        // Yeni şifre hashle ve kaydet
        let context = PersistenceController.shared.container.viewContext
        let newSalt = SecurityManager.shared.generateSalt()
        let hashedPassword = SecurityManager.shared.hashPassword(newPassword, salt: newSalt)
        
        user.password = hashedPassword
        user.passwordSalt = newSalt
        
        do {
            try context.save()
            alertTitle = "Başarılı"
            alertMessage = "Şifreniz başarıyla değiştirildi."
            showAlert = true
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            showPasswordChange = false
            isLoading = false
        } catch {
            alertTitle = "Hata"
            alertMessage = "Şifre güncellenemedi: \(error.localizedDescription)"
            showAlert = true
            isLoading = false
        }
    }
    
    // URL'den resim yükleme
    private func loadImageFromURL(urlString: String) {
        guard let url = URL(string: urlString) else { 
            logWarning("Geçersiz URL: \(urlString)")
            return 
        }
        
        logInfo("Cloudinary URL'den resim yükleniyor: \(urlString)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                logError("Profil resmi yüklenemedi: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logError("Sunucu yanıtı hatalı: \(String(describing: response))")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                logSuccess("URL'den resim başarıyla yüklendi")
                DispatchQueue.main.async {
                    self.selectedImage = image
                    
                    // Resmi yerel olarak da kaydet
                    guard let user = self.currentUser else { return }
                    
                    user.profileImage = data
                    do {
                        try PersistenceController.shared.container.viewContext.save()
                        logSuccess("Resim yerel olarak kaydedildi")
                        
                        // Profil resmi güncellendiği için bildirim gönder
                        NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
                    } catch {
                        logError("Profil resmi yerel olarak kaydedilemedi: \(error)")
                    }
                }
            } else {
                logError("Resim verisi dönüştürülemedi")
            }
        }
        
        task.resume()
    }
    
    // Cloudinary'ye resim yükleme
    private func uploadImageToCloudinary(_ image: UIImage) {
        guard let user = currentUser, let userId = user.id?.uuidString else {
            alertTitle = "Hata"
            alertMessage = "Kullanıcı bilgisi bulunamadı."
            showAlert = true
            return
        }
        
        isUploadingImage = true
        uploadProgress = 0.1 // Başladığını göstermek için
        
        // Resmi sıkıştır
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            isUploadingImage = false
            alertTitle = "Hata"
            alertMessage = "Fotoğraf yüklenemedi. Lütfen tekrar deneyin."
            showAlert = true
            return
        }
        
        // Önce yerel olarak kaydet
        user.profileImage = imageData
        do {
            try PersistenceController.shared.container.viewContext.save()
            logSuccess("Resim yerel olarak kaydedildi")
        } catch {
            logError("Resim yerel olarak kaydedilemedi: \(error)")
        }
        
        // Cloudinary URL'sini oluştur
        let uploadURL = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
        guard let url = URL(string: uploadURL) else {
            isUploadingImage = false
            logError("Geçersiz Cloudinary URL: \(uploadURL)")
            alertTitle = "Hata"
            alertMessage = "Cloudinary bağlantısı oluşturulamadı."
            showAlert = true
            return
        }
        
        logInfo("Cloudinary'ye yükleme başlatılıyor: \(uploadURL)")
        logInfo("Kullanıcı: \(userId)")
        logInfo("Preset: \(uploadPreset)")
        
        // MultipartFormData oluştur
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Form data oluştur
        var body = Data()
        
        // Upload preset ekle
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        
        // Benzersiz bir public_id kullan (kullanıcı ID + zaman damgası + rastgele string)
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomString = UUID().uuidString.prefix(8)
        let uniquePublicId = "profile_\(userId)_\(timestamp)_\(randomString)"
        
        logInfo("Benzersiz profil resmi ID: \(uniquePublicId)")
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"public_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uniquePublicId)\r\n".data(using: .utf8)!)
        
        // Resim dosyasını ekle
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Sınırı kapat
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // HTTP isteği oluştur
        let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                self.isUploadingImage = false
                
                if let error = error {
                    logError("Cloudinary yükleme hatası: \(error.localizedDescription)")
                    self.alertTitle = "Hata"
                    self.alertMessage = "Fotoğraf yüklenemedi: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    logInfo("Cloudinary yanıt kodu: \(httpResponse.statusCode)")
                    
                    // Yanıtın header'larını yazdır
                    logInfo("Yanıt başlıkları:")
                    for (key, value) in httpResponse.allHeaderFields {
                        logInfo("\(key): \(value)")
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        logError("Başarısız yanıt kodu: \(httpResponse.statusCode)")
                        self.alertTitle = "Hata"
                        self.alertMessage = "Sunucu yanıtı hatalı: HTTP \(httpResponse.statusCode)"
                        self.showAlert = true
                        return
                    }
                }
                
                guard let data = data else {
                    logError("Yanıt verisi boş")
                    self.alertTitle = "Hata"
                    self.alertMessage = "Yanıt verisi alınamadı"
                    self.showAlert = true
                    return
                }
                
                // Yanıt verisini yazdır
                if let responseString = String(data: data, encoding: .utf8) {
                    logInfo("Cloudinary yanıtı: \(responseString)")
                }
                
                // JSON yanıtını işle
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        logSuccess("JSON yanıtı alındı")
                        
                        if let secureUrl = json["secure_url"] as? String {
                            logInfo("Yüklenen resim URL: \(secureUrl)")
                            
                            // URL'yi kullanıcı bilgilerine kaydet
                            let context = PersistenceController.shared.container.viewContext
                            user.photoURL = secureUrl
                            
                            do {
                                try context.save()
                                logSuccess("Resim URL'si CoreData'ya kaydedildi")
                                
                                // Firebase'e URL'yi kaydet
                                if let firebaseUID = user.firebaseUID {
                                    logInfo("Profil resmi URL'si Firebase'e gönderiliyor...")
                                    PersistenceController.shared.db.collection("users").document(firebaseUID).updateData([
                                        "photoURL": secureUrl
                                    ]) { error in
                                        if let error = error {
                                            logError("Firebase profil resmi güncelleme hatası: \(error.localizedDescription)")
                                        } else {
                                            logSuccess("Profil resmi URL'si Firebase'e kaydedildi")
                                            
                                            // ProfileImageUpdated bildirimini gönder
                                            NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
                                        }
                                    }
                                } else {
                                    logWarning("Kullanıcının Firebase UID'si yok, Firebase güncellemesi yapılamadı")
                                    
                                    // Firebase ID olmasa da profil resmi güncellendiğinde bildirim gönder
                                    NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
                                }
                                
                                // Uyarı mesajını göster ve işlemi tamamla
                                self.alertTitle = "Başarılı"
                                self.alertMessage = "Profil fotoğrafınız başarıyla güncellendi."
                                self.showAlert = true
                            } catch {
                                logError("CoreData kayıt hatası: \(error.localizedDescription)")
                                self.alertTitle = "Hata"
                                self.alertMessage = "Profil fotoğrafı bilgisi kaydedilemedi: \(error.localizedDescription)"
                                self.showAlert = true
                            }
                        } else {
                            logError("JSON'da secure_url alanı bulunamadı")
                            if let error = json["error"] as? [String: Any] {
                                logError("Cloudinary hata detayı: \(error)")
                            }
                            self.alertTitle = "Hata"
                            self.alertMessage = "Resim URL'si alınamadı"
                            self.showAlert = true
                        }
                    } else {
                        logError("Yanıt JSON formatında değil")
                        self.alertTitle = "Hata"
                        self.alertMessage = "Resim URL'si alınamadı"
                        self.showAlert = true
                    }
                } catch {
                    logError("JSON ayrıştırma hatası: \(error.localizedDescription)")
                    self.alertTitle = "Hata"
                    self.alertMessage = "JSON işleme hatası: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
        
        // İlerleme işlemi
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !isUploadingImage {
                timer.invalidate()
                return
            }
            
            uploadProgress = min(0.9, uploadProgress + 0.1)
        }
        
        // İsteği başlat
        task.resume()
    }
}

// Resim seçici yapı
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    var didSelectImage: ((UIImage?) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { 
                parent.didSelectImage?(nil)
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        let uiImage = image as? UIImage
                        self.parent.selectedImage = uiImage
                        self.parent.didSelectImage?(uiImage)
                    }
                }
            }
        }
    }
}

// Data uzantısı (multipart form data için)
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

struct LoginViewContainer: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isPresented = true
    @State private var currentUser: NSManagedObject? = nil
    
    var body: some View {
        LoginView(isPresented: $isPresented, currentUser: $currentUser)
            .onChange(of: isPresented) { oldValue, newValue in
                if !newValue {
                    // Login görünümü kapatıldığında NavigationView'ı da kapat
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onChange(of: currentUser) { oldValue, newValue in
                if newValue != nil {
                    // Kullanıcı giriş yaptığında NavigationView'ı kapat
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationBarHidden(true)
    }
}

struct RegisterViewContainer: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isPresented = true
    @State private var currentUser: NSManagedObject? = nil
    
    var body: some View {
        RegisterView(isPresented: $isPresented, currentUser: $currentUser)
            .onChange(of: isPresented) { oldValue, newValue in
                if !newValue {
                    // Register görünümü kapatıldığında NavigationView'ı da kapat
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onChange(of: currentUser) { oldValue, newValue in
                if newValue != nil {
                    // Kullanıcı kayıt olduğunda NavigationView'ı kapat
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationBarHidden(true)
    }
} 
