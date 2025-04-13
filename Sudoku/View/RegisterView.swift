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
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Logo ve başlık
                    VStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Kayıt Ol")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Kayıt formu
                    VStack(spacing: 20) {
                        // Ad Soyad
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ad Soyad")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Adınızı ve soyadınızı girin", text: $name)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // E-posta
                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-posta")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("E-posta adresinizi girin", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Kullanıcı adı
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kullanıcı Adı")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Kullanıcı adınızı girin", text: $username)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Şifre")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Şifrenizi girin", text: $password)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Şifre onay
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Şifre Onayı")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Şifrenizi tekrar girin", text: $confirmPassword)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Kayıt butonu
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
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isFormInvalid || isLoading)
                        .opacity((isFormInvalid || isLoading) ? 0.6 : 1)
                        
                        // İptal butonu
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("İptal")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Kayıt Hatası"), message: Text(errorMessage), dismissButton: .default(Text("Tamam")))
        }
    }
    
    private var isFormInvalid: Bool {
        return name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty || password != confirmPassword
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
        
        // E-posta kontrol
        if !isValidEmail(email) {
            errorMessage = "Geçerli bir e-posta adresi girin."
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
                } else {
                    // Başarısız kayıt
                    errorMessage = "Bu kullanıcı adı veya e-posta zaten kullanılıyor."
                    showError = true
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
} 
