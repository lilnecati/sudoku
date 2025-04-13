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
    
    // View performansı için çıktıları önbelleğe alma
    @ViewBuilder private func loginButton(isDisabled: Bool) -> some View {
        Button(action: loginUser) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .blue))
            } else {
                Text("Giriş Yap")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .shadow(color: Color.purple.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: colorScheme == .dark ? 10 : 5, x: 0, y: 5)
    }
    
    // Klavyeyi kapat
    private func dismissKeyboard() {
        focusUsername = false
        focusPassword = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        ZStack {
            // Izgara arka planı - ağır arka plan animasyonlarını kaldırdık
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Ana içerik için ScrollView
            ScrollView {
                VStack(spacing: 20) {
                    // Logo ve başlık - Basit hale getirildi
                    VStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Giriş Yap")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // Giriş formu - Basitleştirildi
                    VStack(spacing: 15) {
                        // Kullanıcı adı
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kullanıcı Adı")
                                .font(.headline)
                            
                            TextField("Kullanıcı adınızı girin", text: $username)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusPassword = true
                                }
                                .focused($focusUsername)
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre")
                                .font(.headline)
                            
                            SecureField("Şifrenizi girin", text: $password)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
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
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        // Giriş butonu - Basitleştirildi
                        Button(action: loginUser) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Giriş Yap")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            (username.isEmpty || password.isEmpty || isLoading) ? 
                                Color.gray : Color.blue
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(username.isEmpty || password.isEmpty || isLoading)
                        
                        // Kayıt ol butonu
                        HStack {
                            Text("Hesabınız yok mu?")
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                dismissKeyboard()
                                isPresented = false
                                NotificationCenter.default.post(name: Notification.Name("ShowRegisterView"), object: nil)
                            }) {
                                Text("Kayıt Ol")
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
        // Ekstra arka plan özelleştirmelerini kaldır
        .animation(nil, value: isLoading) // Animasyonu kaldır
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
        
        // Giriş işlemi
        DispatchQueue.global().async {
            let result = PersistenceController.shared.loginUser(username: username, password: password)
            
            DispatchQueue.main.async {
                isLoading = false
                
                if let user = result {
                    // Başarılı giriş
                    currentUser = user
                    isPresented = false
                    
                    // Kullanıcı giriş bildirimini gönder
                    NotificationCenter.default.post(name: Notification.Name("UserLoggedIn"), object: nil)
                    
                    // Başarılı giriş titreşimi
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                } else {
                    // Başarısız giriş
                    errorMessage = "Kullanıcı adı veya şifre hatalı."
                    showError = true
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
