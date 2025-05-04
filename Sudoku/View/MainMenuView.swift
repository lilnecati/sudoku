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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var hasSavedGame: Bool = false
    @State private var showSettings: Bool = false
    
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        // NavigationView GEÇİCİ OLARAK kaldırıldı
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            /* // Ana VStack GEÇİCİ OLARAK yorum satırına alındı
            VStack(spacing: 25) {
                // Animasyonlu logo ve başlık
                // ... 
                
                Spacer()
                
                // Ana menü butonları
                // ...
                
                Spacer()
            }
            */
        }
        .sheet(isPresented: $showSettings) {
            // NavigationView kaldırıldı, SettingsView doğrudan çağrılıyor
            SettingsView(showView: $showSettings)
            .preferredColorScheme(themeManager.colorScheme) // Sheet'in de tema uyumlu olmasını sağla
        }
        // .navigationViewStyle(StackNavigationViewStyle()) kaldırıldı
        .onAppear {
            checkForSavedGame()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceRefreshUI"))) { _ in
            // Bu bildirim alındığında görünümün yenilenmesi için bir state değişikliği yapar
            logInfo("MainMenuView: ForceRefreshUI bildirimi alındı")
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
    let isBejMode: Bool
    
    var body: some View {
        HStack {
            // İkon
            ZStack {
                Circle()
                    .fill(color.opacity(isBejMode ? 0.2 : (colorScheme == .dark ? 0.3 : 0.15)))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: isBejMode ? 1 : (colorScheme == .dark ? 2 : 1))
                            .blur(radius: isBejMode ? 0 : (colorScheme == .dark ? 2 : 0))
                    )
                    .shadow(color: color.opacity(isBejMode ? 0.4 : (colorScheme == .dark ? 0.8 : 0.3)), radius: 8, x: 0, y: 0)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : (colorScheme == .dark ? .white : color))
            }
            
            // Başlık
            Text(title)
                .font(.title3.bold())
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : (colorScheme == .dark ? .white : .black))
            
            Spacer()
            
            // Sağ ok işareti
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : (colorScheme == .dark ? .white.opacity(0.8) : .gray))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            ZStack {
                // Arkaplan
                RoundedRectangle(cornerRadius: 16)
                    .fill(isBejMode ? 
                          ThemeManager.BejThemeColors.cardBackground : 
                          (colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.7)))
                
                // Kenar çizgileri
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(isBejMode ? 0.4 : (colorScheme == .dark ? 0.7 : 0.3)), 
                                color.opacity(isBejMode ? 0.2 : (colorScheme == .dark ? 0.3 : 0.1))
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isBejMode ? 1.0 : (colorScheme == .dark ? 1.5 : 1.0)
                    )
            }
        )
        .shadow(color: color.opacity(isBejMode ? 0.3 : (colorScheme == .dark ? 0.4 : 0.2)), 
                radius: isBejMode ? 6 : (colorScheme == .dark ? 10 : 5), x: 0, y: 4)
    }
}

#Preview {
    MainMenuView()
} 
