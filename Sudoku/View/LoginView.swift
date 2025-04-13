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
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Logo ve başlık
                    VStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Giriş Yap")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                    
                    // Giriş formu
                    VStack(spacing: 20) {
                        // Kullanıcı adı
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kullanıcı Adı")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            TextField("Kullanıcı adınızı girin", text: $username)
                                .padding()
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                                )
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        
                        // Şifre
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Şifre")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            SecureField("Şifrenizi girin", text: $password)
                                .padding()
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.5 : 0.3), lineWidth: 1)
                                )
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        
                        // Giriş butonu
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
                        .disabled(username.isEmpty || password.isEmpty || isLoading)
                        .opacity((username.isEmpty || password.isEmpty || isLoading) ? 0.6 : 1)
                        .shadow(color: Color.purple.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: colorScheme == .dark ? 10 : 5, x: 0, y: 5)
                        
                        // İptal butonu
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("İptal")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Giriş Hatası"), message: Text(errorMessage), dismissButton: .default(Text("Tamam")))
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
        
        // Giriş işlemi
        DispatchQueue.global().async {
            let result = PersistenceController.shared.loginUser(username: username, password: password)
            
            DispatchQueue.main.async {
                isLoading = false
                
                if let user = result {
                    // Başarılı giriş
                    currentUser = user
                    isPresented = false
                } else {
                    // Başarısız giriş
                    errorMessage = "Kullanıcı adı veya şifre hatalı."
                    showError = true
                }
            }
        }
    }
} 
