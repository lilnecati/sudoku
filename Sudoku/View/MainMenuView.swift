import SwiftUI
import CoreData
import Combine

struct MainMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasSavedGame: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Animasyonlu logo ve başlık
                VStack(spacing: 10) {
                    // Sistem ikonu kullanarak logo
                    Image(systemName: "grid.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ColorManager.primaryBlue, ColorManager.primaryGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Sudoku")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Ana menü butonları
                VStack(spacing: 15) {
                    // Yeni Oyun butonu
                    NavigationLink {
                        GameView(difficulty: .easy)
                    } label: {
                        MenuButton(
                            title: "Yeni Oyun",
                            icon: "play.fill",
                            color: ColorManager.primaryGreen
                        )
                    }
                    
                    // Devam Et butonu
                    if hasSavedGame {
                        NavigationLink {
                            if let savedGame = loadLastGame() {
                                GameView(savedGame: savedGame)
                            }
                        } label: {
                            MenuButton(
                                title: "Devam Et",
                                icon: "arrow.clockwise",
                                color: ColorManager.primaryBlue
                            )
                        }
                    }
                    
                    // Skor Tablosu butonu
                    NavigationLink {
                        ScoreboardView()
                    } label: {
                        MenuButton(
                            title: "Skor Tablosu",
                            icon: "trophy.fill",
                            color: ColorManager.primaryOrange
                        )
                    }
                    
                    // Ayarlar butonu
                    NavigationLink {
                        SettingsView()
                    } label: {
                        MenuButton(
                            title: "Ayarlar",
                            icon: "gearshape.fill",
                            color: ColorManager.primaryPurple
                        )
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color(.systemGray6) : .white,
                        colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            )
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
            print("Kaydedilmiş oyun kontrolü başarısız: \(error)")
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
            print("Son oyun yüklenemedi: \(error)")
            return nil
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color)
                )
            
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    MainMenuView()
} 