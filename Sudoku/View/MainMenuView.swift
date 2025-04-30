//  MainMenuView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI
import CoreData
import Combine

struct MainMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasSavedGame: Bool = false
    @State private var showSettings: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Izgara arka planı
                GridBackgroundView()
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    // Animasyonlu logo ve başlık
                    VStack(spacing: 10) {
                        // Sistem ikonu kullanarak logo
                        Image(systemName: "grid.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .purple.opacity(0.6), radius: 10, x: 0, y: 0)
                        
                        Text("SUDOKU")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .shadow(color: .blue.opacity(0.6), radius: 5, x: 0, y: 0)
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Ana menü butonları
                    VStack(spacing: 18) {
                        // Yeni Oyun butonu
                        NavigationLink {
                            GameView(difficulty: .easy)
                        } label: {
                            NeonMenuButton(
                                title: "Yeni Oyun",
                                icon: "play.fill",
                                color: .green,
                                colorScheme: colorScheme
                            )
                        }
                        
                        // Devam Et butonu
                        if hasSavedGame {
                            NavigationLink {
                                if let savedGame = loadLastGame() {
                                    GameView(savedGame: savedGame)
                                }
                            } label: {
                                NeonMenuButton(
                                    title: "Devam Et",
                                    icon: "arrow.clockwise",
                                    color: .blue,
                                    colorScheme: colorScheme
                                )
                            }
                        }
                        
                        // Skor Tablosu butonu
                        NavigationLink {
                            ScoreboardView()
                        } label: {
                            NeonMenuButton(
                                title: "Skor Tablosu",
                                icon: "trophy.fill",
                                color: .orange,
                                colorScheme: colorScheme
                            )
                        }
                        
                        // Ayarlar butonu
                        Button {
                            showSettings = true
                        } label: {
                            NeonMenuButton(
                                title: "Ayarlar",
                                icon: "gearshape.fill",
                                color: .purple,
                                colorScheme: colorScheme
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(showView: $showSettings)
            }
        }
        .onAppear {
            checkForSavedGame()
        }
    }
    
    private func checkForSavedGame() {
        // Kaydedilmiş oyun kontrolü
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SavedGame")
        fetchRequest.fetchLimit = 1
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let count = try context.count(for: fetchRequest)
            hasSavedGame = count > 0
        } catch {
            logError("Kaydedilmiş oyun kontrolü başarısız: \(error)")
            hasSavedGame = false
        }
    }
    
    private func loadLastGame() -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SavedGame")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            logError("Son oyun yüklenemedi: \(error)")
            return nil
        }
    }
}

// Neon efektli menü butonu
struct NeonMenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack {
            // İkon
            ZStack {
                Circle()
                    .fill(color.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: colorScheme == .dark ? 2 : 1)
                            .blur(radius: colorScheme == .dark ? 2 : 0)
                    )
                    .shadow(color: color.opacity(colorScheme == .dark ? 0.8 : 0.3), radius: 8, x: 0, y: 0)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(colorScheme == .dark ? .white : color)
            }
            
            // Başlık
            Text(title)
                .font(.title3.bold())
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            // Sağ ok işareti
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                // Arkaplan
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? 
                          Color.black.opacity(0.5) : 
                          Color.white.opacity(0.7))
                
                // Kenar çizgileri
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(colorScheme == .dark ? 0.7 : 0.3), 
                                color.opacity(colorScheme == .dark ? 0.3 : 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: colorScheme == .dark ? 1.5 : 1.0
                    )
            }
        )
        .shadow(color: color.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: colorScheme == .dark ? 10 : 5, x: 0, y: 4)
    }
}

#Preview {
    MainMenuView()
} 
