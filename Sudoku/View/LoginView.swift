// LoginView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 10.10.2024.
//

import SwiftUI
import CoreData

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var isPresented: Bool
    @Binding var currentUser: NSManagedObject?
    
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLoading = false
    @State private var showForgotPassword = false
    
    // Focus States kullanarak metinlerin odak kontrolü
    @FocusState private var focusUsername: Bool
    @FocusState private var focusPassword: Bool
    
    // Klavye çıkıp çıkmadığını izleyecek state
    @State private var keyboardIsVisible = false
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // View performansı için çıktıları önbelleğe alma
    @ViewBuilder private func loginButton(isDisabled: Bool) -> some View {
        Button(action: loginUser) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: isBejMode ? 
                                                                ThemeManager.BejThemeColors.text : 
                                                                (colorScheme == .dark ? .white : .blue)))
            } else {
                Text("Giriş Yap")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(isDisabled ? Color.gray : Color.blue.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(12)
        .disabled(isDisabled)
        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
    }
    
    // Klavyeyi kapat
    private func dismissKeyboard() {
        focusUsername = false
        focusPassword = false
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
            
            // Ana içerik için ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    // Logo ve başlık
                    VStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                            .shadow(color: (isBejMode ? ThemeManager.BejThemeColors.accent : .blue).opacity(0.3), radius: 5, x: 0, y: 3)
                        
                        Text("Giriş Yap")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    
                    // Giriş formu
                    VStack(spacing: 15) {
                        // Kullanıcı adı
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kullanıcı Adı")
                                .font(.headline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
                            TextField("Kullanıcı adınızı girin", text: $username)
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
                                .onSubmit {
                                    focusPassword = true
                                }
                                .focused($focusUsername)
                                .onAppear {
                                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                                        keyboardIsVisible = true
                                    }
                                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                                        keyboardIsVisible = false
                                    }
                                }
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre")
                                .font(.headline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                            
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
                                .submitLabel(.done)
                                .onSubmit {
                                    if !username.isEmpty && !password.isEmpty {
                                        loginUser()
                                    }
                                }
                                .focused($focusPassword)
                        }
                        
                        // Şifremi Unuttum
                        Button(action: {
                            dismissKeyboard()
                            showForgotPassword = true
                        }) {
                            Text("Şifremi Unuttum")
                                .font(.subheadline)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        // Giriş butonu
                        Button(action: loginUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: isBejMode ? 
                                                                                ThemeManager.BejThemeColors.text : 
                                                                                .white))
                            } else {
                                Text("Giriş Yap")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((username.isEmpty || password.isEmpty || isLoading) ? 
                                   Color.gray : 
                                   (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue.opacity(0.8)))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.cardBackground : .white)
                        .cornerRadius(12)
                        .shadow(color: (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue).opacity(0.3), radius: 5, x: 0, y: 3)
                        .disabled(username.isEmpty || password.isEmpty || isLoading)
                        
                        // Kayıt ol butonu
                        HStack {
                            Text("Hesabınız yok mu?")
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                            
                            Button(action: {
                                dismissKeyboard()
                                isPresented = false
                                NotificationCenter.default.post(name: Notification.Name("ShowRegisterView"), object: nil)
                            }) {
                                Text("Kayıt Ol")
                                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
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
                                .background(isBejMode ? 
                                           ThemeManager.BejThemeColors.background.opacity(0.1) : 
                                           Color(UIColor.secondarySystemBackground))
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: 500)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately) // Otomatik yerine anında klavyeyi kapat
            .hideKeyboardWhenTappedOutside() // Ekranın boş bir yerine dokunulduğunda klavyeyi kapat
            // Hata mesajı gösterme
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Hata"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("Tamam"))
                )
            }
            // Şifremi unuttum gösterme
            .sheet(isPresented: $showForgotPassword) {
                forgotPasswordView
            }
        }
    }
    
    private func loginUser() {
        isLoading = true
        
        // Basit doğrulama
        if username.isEmpty || password.isEmpty {
            errorMessage = "Kullanıcı adı ve şifre gereklidir."
            showError = true
            isLoading = false
            return
        }
        
        // Email veya kullanıcı adını işle
        let emailToUse = PersistenceController.shared.getEmailFromUsername(username)
        
        // Önce kullanıcı adıyla yerel oturumu deneyelim
        DispatchQueue.global().async {
            let localResult = PersistenceController.shared.loginUser(username: self.username, password: self.password)
            
            if let user = localResult {
                // Yerel giriş başarılı
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentUser = user
                    self.isPresented = false
                    
                    // Kullanıcı giriş bildirimini gönder
                    NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                    
                    // Başarılı giriş titreşimi
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                return
            }
            
            // Yerel giriş başarısız, Firebase ile devam edelim
            DispatchQueue.main.async {
                // Önce Firebase'de giriş dene
                PersistenceController.shared.loginUserWithFirebase(email: emailToUse, password: self.password) { user, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if let user = user {
                            // Firebase giriş başarılı
                            self.currentUser = user
                            self.isPresented = false
                            
                            // Kullanıcı giriş bildirimini gönder
                            NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                            
                            // Başarılı giriş titreşimi
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                        } else {
                            // Başarısız giriş
                            if let error = error {
                                self.errorMessage = "Giriş hatası: \(error.localizedDescription)"
                            } else {
                                self.errorMessage = "Kullanıcı adı veya şifre hatalı."
                            }
                            self.showError = true
                        }
                    }
                }
            }
        }
    }
    
    // Şifremi Unuttum ekranı
    private var forgotPasswordView: some View {
        VStack(spacing: 20) {
            Text("Şifremi Unuttum")
                .font(.title)
                .bold()
                .padding(.top, 30)
            
            Text("Hesabınıza bağlı e-posta adresinizi girin, şifre sıfırlama talimatlarını göndereceğiz.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            // E-posta girişi
            TextField("E-posta adresiniz", text: .constant(""))
                .padding()
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            // Gönder butonu
            Button(action: {
                // Şifre sıfırlama talimatları gönder
                showForgotPassword = false
                // NOT: Bu özellik henüz uygulanmadı
                errorMessage = "Bu özellik şu anda yapım aşamasındadır. Lütfen daha sonra tekrar deneyin."
                showError = true
            }) {
                Text("Talimatları Gönder")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // İptal butonu
            Button(action: {
                showForgotPassword = false
            }) {
                Text("İptal")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white
        )
    }
} 
