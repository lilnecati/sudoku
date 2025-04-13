import SwiftUI
import CoreData

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    
    @State private var showPasswordChange = false
    
    // Mevcut kullanıcı bilgilerini yükle
    private var currentUser: User? {
        return PersistenceController.shared.getCurrentUser()
    }
    
    var body: some View {
        ZStack {
            // Arka plan
            GridBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Profil Başlığı
                    profileHeader
                    
                    // Profil düzenleme formu
                    profileForm
                    
                    // Şifre değiştirme butonları
                    passwordChangeSection
                    
                    // Hesap silme butonu
                    deleteAccountButton
                    
                    Spacer()
                }
                .padding()
                .onAppear(perform: loadUserData)
            }
        }
        .navigationTitle("Profil Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Kaydet") {
                    saveProfile()
                }
                .disabled(isLoading)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("Tamam"))
            )
        }
        .actionSheet(isPresented: $showDeleteConfirmation) {
            ActionSheet(
                title: Text("Hesabı Sil"),
                message: Text("Bu işlem geri alınamaz. Tüm verileriniz silinecektir."),
                buttons: [
                    .destructive(Text("Hesabı Sil")) {
                        // Hesap silme işlemi - henüz uygulanmadı
                        alertTitle = "Bilgi"
                        alertMessage = "Bu özellik şu anda geliştirme aşamasındadır."
                        showAlert = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // Profil başlık kısmı
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Profil resmi
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Text(String(name.prefix(1)))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            // Kullanıcı adı
            Text("@\(username)")
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
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                    )
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
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                    )
            }
            
            // Kullanıcı Adı
            VStack(alignment: .leading, spacing: 8) {
                Text("Kullanıcı Adı")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Kullanıcı adınızı girin", text: $username)
                    .padding()
                    .autocapitalization(.none)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                    )
                    .disabled(true) // Kullanıcı adı değiştirilemez
                    .foregroundColor(.gray)
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
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
            }
            
            // Şifre değiştirme formu - koşullu olarak göster
            if showPasswordChange {
                VStack(spacing: 15) {
                    // Mevcut şifre
                    SecureField("Mevcut Şifre", text: $currentPassword)
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                        )
                    
                    // Yeni şifre
                    SecureField("Yeni Şifre", text: $newPassword)
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                        )
                    
                    // Yeni şifre onay
                    SecureField("Yeni Şifre (Tekrar)", text: $confirmPassword)
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                        )
                    
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
                        .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .transition(.opacity)
                .animation(.easeInOut, value: showPasswordChange)
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
        
        // Kaydet
        user.name = name
        user.email = email
        
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