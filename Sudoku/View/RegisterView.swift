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
    
    // Focus states
    @FocusState private var focusName: Bool
    @FocusState private var focusEmail: Bool
    @FocusState private var focusUsername: Bool
    @FocusState private var focusPassword: Bool
    @FocusState private var focusConfirmPassword: Bool
    
    // Doğrulama durumları
    @State private var usernameValidationMessage = ""
    @State private var emailValidationMessage = ""
    @State private var passwordValidationMessage = ""
    @State private var confirmPasswordValidationMessage = ""
    
    @State private var showStrongPasswordInfo = false
    
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
            // Basit arka plan - GridBackgroundView yerine düz renk
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Başlık - basitleştirildi
                    Text("Yeni Hesap Oluştur")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        // Ad Soyad - basitleştirildi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ad Soyad")
                                .font(.headline)
                            
                            TextField("Adınızı ve soyadınızı girin", text: $name)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($focusName)
                                .submitLabel(.next)
                                .onSubmit { focusEmail = true }
                        }
                        
                        // E-posta - basitleştirildi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-posta")
                                .font(.headline)
                            
                            TextField("E-posta adresinizi girin", text: $email)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .focused($focusEmail)
                                .submitLabel(.next)
                                .onSubmit { focusUsername = true }
                        }
                        
                        // Kullanıcı adı - basitleştirildi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kullanıcı Adı")
                                .font(.headline)
                            
                            TextField("En az 4 karakter", text: $username)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusUsername)
                                .submitLabel(.next)
                                .onSubmit { focusPassword = true }
                        }
                        
                        // Şifre - basitleştirildi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre")
                                .font(.headline)
                            
                            SecureField("Şifrenizi girin", text: $password)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($focusPassword)
                                .submitLabel(.next)
                                .onSubmit { focusConfirmPassword = true }
                            
                            // Parola gücü bilgisi - basitleştirildi
                            if !password.isEmpty {
                                let passwordCheck = SecurityManager.shared.isStrongPassword(password)
                                Text(passwordCheck.message)
                                    .font(.caption)
                                    .foregroundColor(passwordCheck.isStrong ? .green : .red)
                            }
                            
                            // Şifre bilgisi butonu
                            Button(action: {
                                dismissKeyboard()
                                showStrongPasswordInfo.toggle()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                    Text("Güçlü şifre nedir?")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Şifre onay - basitleştirildi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre Onayı")
                                .font(.headline)
                            
                            SecureField("Şifrenizi tekrar girin", text: $confirmPassword)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($focusConfirmPassword)
                                .submitLabel(.done)
                                .onSubmit {
                                    dismissKeyboard()
                                    if !isFormInvalid {
                                        registerUser()
                                    }
                                }
                            
                            // Şifre eşleşme bilgisi - basitleştirildi
                            if !confirmPassword.isEmpty {
                                if password == confirmPassword {
                                    Text("Şifreler eşleşiyor")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Şifreler eşleşmiyor")
                                    .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Kayıt Ol butonu - basitleştirildi
                        Button(action: registerUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Kayıt Ol")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isFormInvalid ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isFormInvalid)
                        
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
                        
                        // İptal butonu - basitleştirildi
                        Button(action: {
                            dismissKeyboard()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("İptal")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: 500) // Ekran genişliğini sınırla
                .padding(.bottom, 20)
            }
            
            // Hata mesajı
        .alert(isPresented: $showError) {
                Alert(
                    title: Text("Hata"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("Tamam"))
                )
        }
        .sheet(isPresented: $showStrongPasswordInfo) {
            passwordInfoSheet
        }
        }
        .animation(nil, value: isLoading) // Animasyonu kaldır
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
    
    private var isFormInvalid: Bool {
        if name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty {
            return true
        }
        
        if password != confirmPassword {
            return true
        }
        
        // Şifre gücü kontrolü
        let passwordCheck = SecurityManager.shared.isStrongPassword(password)
        if !passwordCheck.isStrong {
            return true
        }
        
        // E-posta kontrolü
        let emailCheck = SecurityManager.shared.isValidEmail(email)
        if !emailCheck.isValid {
            return true
        }
        
        // Kullanıcı adı kontrolü
        let usernameCheck = SecurityManager.shared.isValidUsername(username)
        if !usernameCheck.isValid {
            return true
        }
        
        return false
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
        
        // Kayıt işlemi
        DispatchQueue.global().async {
            let success = PersistenceController.shared.registerUser(
                username: username,
                password: password,
                email: email,
                name: name
            )
            
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    // Başarılı kayıt
                    currentUser = PersistenceController.shared.fetchUser(username: username)
                    isPresented = false
                    
                    // Kullanıcı giriş bildirimini gönder
                    NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                    
                    // Başarılı kayıt titreşimi
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                } else {
                    // Başarısız kayıt
                    errorMessage = "Bu kullanıcı adı veya e-posta zaten kullanılıyor."
                    showError = true
                }
            }
        }
    }
    
    // Güçlü şifre bilgisi sayfası
    var passwordInfoSheet: some View {
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
                showStrongPasswordInfo = false
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
