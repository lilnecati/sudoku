//  RegisterView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//


import SwiftUI
import CoreData

struct RegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // ThemeManager eklendi
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var isPresented: Bool
    @Binding var currentUser: NSManagedObject?
    
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var email = ""
    @State private var name = "Necati Yıldırım" 
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLoading = false
    
    // Klavye çıkıp çıkmadığını izleyecek state
    @State private var keyboardIsVisible = false
    
    // Focus states
    @FocusState private var focusName: Bool
    @FocusState private var focusEmail: Bool
    @FocusState private var focusUsername: Bool
    @FocusState private var focusPassword: Bool
    @FocusState private var focusConfirmPassword: Bool
    
    // Doğrulama durumları
    @State private var usernameValidationMessage = ""
    @State private var emailValidationMessage = ""
    @State private var passwordStrengthMessage = ""
    @State private var isUsernameValid = false
    @State private var isEmailValid = false
    @State private var isPasswordStrong = false
    @State private var showingPasswordInfo = false
    
    // Bej mod kontrolü için hesaplama eklendi
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Performans için önbelleğe alma
    @ViewBuilder private func registerButton(isDisabled: Bool) -> some View {
        Button(action: registerUser) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Kayıt Ol")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(isDisabled ? Color.gray : Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(isDisabled)
    }
    
    // Arayüz bileşenlerini önbelleğe alarak daha az hesaplama yapılmasını sağlar
    private func inputField(title: String, placeholder: String, value: Binding<String>, isSecure: Bool = false, keyboardType: UIKeyboardType = .default, focusState: FocusState<Bool>.Binding, submitLabel: SubmitLabel = .next, onSubmit: @escaping () -> Void = {}) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: value)
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                } else {
                    TextField(placeholder, text: value)
                        .keyboardType(keyboardType)
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                }
            }
            .focused(focusState)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
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
                VStack(spacing: 20) {
                    // Başlık
                    Text("Yeni Hesap Oluştur")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    VStack(spacing: 16) {
                        // Ad Soyad
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ad Soyad")
                                .font(.headline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
                            TextField("Adınızı ve soyadınızı girin", text: $name)
                                .padding()
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBejMode ? 
                                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                                               Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .submitLabel(.next)
                                .onSubmit { focusEmail = true }
                                .focused($focusName)
                        }
                        
                        // E-posta
                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-posta")
                                .font(.headline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
                            TextField("E-posta adresinizi girin", text: $email)
                                .padding()
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBejMode ? 
                                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                                               Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .submitLabel(.next)
                                .onSubmit { focusUsername = true }
                                .focused($focusEmail)
                                .onChange(of: email) {
                                    validateEmail(email)
                                }
                        }
                        
                        // Kullanıcı Adı
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Kullanıcı Adı")
                                    .font(.headline)
                                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                
                                Text("(Zorunlu ve Değiştirilemez)")
                                    .font(.caption)
                                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .orange)
                            }
                            
                            Text("Kullanıcı adınız benzersiz olmalı ve daha sonra değiştirilemez.")
                                .font(.caption)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                            
                            TextField("Benzersiz kullanıcı adı (en az 4 karakter)", text: $username)
                                .padding()
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBejMode ? 
                                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                                               Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                                .onSubmit { focusPassword = true }
                                .focused($focusUsername)
                                .onChange(of: username) {
                                    validateUsername(username)
                                }
                            
                            if !usernameValidationMessage.isEmpty {
                                Text(usernameValidationMessage)
                                    .font(.caption)
                                    .foregroundColor(isUsernameValid ? .green : .red)
                            }
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Şifre")
                                    .font(.headline)
                                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                Spacer()
                                Button(action: {
                                    showingPasswordInfo = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                                    Text("Güçlü şifre nedir?")
                                        .font(.caption)
                                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                                }
                            }
                            
                            SecureField("Şifrenizi girin", text: $password)
                                .padding()
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBejMode ? 
                                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                                               Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .submitLabel(.next)
                                .onSubmit { focusConfirmPassword = true }
                                .focused($focusPassword)
                                .onChange(of: password) {
                                    validatePasswordStrength(password)
                                }
                            
                            if !passwordStrengthMessage.isEmpty {
                                Text(passwordStrengthMessage)
                                    .font(.caption)
                                    .foregroundColor(isPasswordStrong ? .green : .red)
                            }
                        }
                        
                        // Şifre Onay
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre Onay")
                                .font(.headline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
                            SecureField("Şifrenizi tekrar girin", text: $confirmPassword)
                                .padding()
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isBejMode ? 
                                               ThemeManager.BejThemeColors.accent.opacity(0.3) : 
                                               Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .submitLabel(.done)
                                .onSubmit {
                                    if isFormValid {
                                        registerUser()
                                    }
                                }
                                .focused($focusConfirmPassword)
                            
                            if !confirmPassword.isEmpty {
                                Text(password == confirmPassword ? "Şifreler eşleşiyor" : "Şifreler eşleşmiyor")
                                    .font(.caption)
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                            }
                        }
                        
                        // Kayıt Ol butonu
                        Button(action: registerUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Kayıt Ol")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!isFormValid ? Color.gray : Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        .disabled(!isFormValid)
                        
                        // Zaten hesabınız var mı butonu
                        HStack {
                            Text("Zaten hesabınız var mı?")
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                dismissKeyboard()
                                isPresented = false
                            }) {
                                Text("Giriş Yap")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // İptal butonu
                        Button(action: {
                            dismissKeyboard()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("İptal")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: 500)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .hideKeyboardWhenTappedOutside()
            
            // Hata mesajı
        .alert(isPresented: $showError) {
                Alert(
                    title: Text("Hata"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("Tamam"))
                )
        }
            
            // Güçlü şifre bilgisi
        .sheet(isPresented: $showingPasswordInfo) {
                strongPasswordInfoView
        }
        }
    }
    
    // Klavyeyi kapat
    private func dismissKeyboard() {
        focusName = false
        focusEmail = false
        focusUsername = false
        focusPassword = false
        focusConfirmPassword = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Form geçerlilik kontrolü (isFormInvalid yerine)
    private var isFormValid: Bool {
         // Basic empty checks
         guard !name.isEmpty, !email.isEmpty, !username.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
             return false
         }
         // Email check
         guard isEmailValid else { return false } // Use the state variable
         // Username check
         guard isUsernameValid else { return false } // Use the state variable
         // Password strength check
         guard isPasswordStrong else { return false } // Use the state variable
         // Password confirmation check
         guard password == confirmPassword else { return false }

         // TODO: Add check for existing username if necessary

         return true
     }
     
    // Kullanıcı adı doğrulama fonksiyonu
    private func validateUsername(_ username: String) {
        let usernameCheck = SecurityManager.shared.isValidUsername(username)
        isUsernameValid = usernameCheck.isValid
        usernameValidationMessage = usernameCheck.message
        // TODO: Check if username exists
    }
    
    // E-posta doğrulama fonksiyonu
    private func validateEmail(_ email: String) {
        let emailCheck = SecurityManager.shared.isValidEmail(email)
        isEmailValid = emailCheck.isValid
        emailValidationMessage = emailCheck.message
    }
    
    // Şifre gücü doğrulama fonksiyonu
    private func validatePasswordStrength(_ password: String) {
        let passwordCheck = SecurityManager.shared.isStrongPassword(password)
        isPasswordStrong = passwordCheck.isStrong
        passwordStrengthMessage = passwordCheck.message
    }

    private func registerUser() {
        isLoading = true
        
        // Form doğrulama
        if name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty {
            errorMessage = "Tüm alanları doldurun."
            showError = true
            isLoading = false
            return
        }
        
        if password != confirmPassword {
            errorMessage = "Şifreler eşleşmiyor."
            showError = true
            isLoading = false
            return
        }
        
        // E-posta doğrulama
        let emailCheck = SecurityManager.shared.isValidEmail(email)
        if !emailCheck.isValid {
            errorMessage = emailCheck.message
            showError = true
            isLoading = false
            return
        }
        
        // Kullanıcı adı doğrulama
        let usernameCheck = SecurityManager.shared.isValidUsername(username)
        if !usernameCheck.isValid {
            errorMessage = usernameCheck.message
            showError = true
            isLoading = false
            return
        }
        
        // Şifre gücü doğrulama
        let passwordCheck = SecurityManager.shared.isStrongPassword(password)
        if !passwordCheck.isStrong {
            errorMessage = passwordCheck.message
            showError = true
            isLoading = false
            return
        }
        
        // Firebase ile kayıt işlemi
        PersistenceController.shared.registerUserWithFirebase(
            username: username,
            password: password,
            email: email,
            name: name
        ) { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Başarılı kayıt
                    self.currentUser = PersistenceController.shared.fetchUser(username: self.username)
                    self.isPresented = false
                    
                    // Kullanıcı giriş bildirimini gönder
                    logInfo("Posting UserLoggedIn notification from RegisterView...")
                    NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                    
                    // Başarılı kayıt titreşimi
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()

                    // Başarı durumunda devam et
                    self.presentationMode.wrappedValue.dismiss()

                    // Kullanıcı giriş yaptı bildirimi gönder
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Kullanıcı giriş bildirimi gönder
                        logInfo("Posting UserLoggedIn notification from RegisterView... done")
                        NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                    }
                } else {
                    // Başarısız kayıt
                    if let error = error {
                        self.errorMessage = "Kayıt hatası: \(error.localizedDescription)"
                    } else {
                        self.errorMessage = "Bu kullanıcı adı veya e-posta zaten kullanılıyor."
                    }
                    self.showError = true
                }
            }
        }
    }
    
    // Güçlü şifre bilgisi sayfası
    var strongPasswordInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Güçlü Şifre Gereksinimleri")
                .font(.title)
                .bold()
                .padding(.bottom, 10)
            
            Group {
                bulletPoint(text: "En az 8 karakter uzunluğunda olmalı")
                bulletPoint(text: "En az bir büyük harf içermeli (A-Z)")
                bulletPoint(text: "En az bir küçük harf içermeli (a-z)")
                bulletPoint(text: "En az bir rakam içermeli (0-9)")
                bulletPoint(text: "En az bir özel karakter içermeli (!, @, #, $, vb.)")
            }
            
            Divider()
                .padding(.vertical, 10)
            
            Text("Güçlü Şifre Örnekleri:")
                .font(.headline)
                .padding(.bottom, 5)
            
            Group {
                Text("• Sudoku2024!")
                Text("• Oyun_Seviyorum1")
                Text("• G1zl!Sudoku")
            }
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.blue)
            
            Spacer()
            
            Button(action: {
                showingPasswordInfo = false
            }) {
                Text("Anladım")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .foregroundColor(.blue)
                .font(.headline)
            Text(text)
                .font(.body)
        }
    }
} 
