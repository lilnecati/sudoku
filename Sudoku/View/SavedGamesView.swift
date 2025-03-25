import SwiftUI
import CoreData

struct SavedGamesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedGame.dateCreated, ascending: false)],
        animation: .default)
    private var savedGames: FetchedResults<SavedGame>
    
    @ObservedObject var viewModel: SudokuViewModel
    @State private var gameToDelete: SavedGame? = nil
    @State private var showingDeleteAlert = false
    @State private var selectedDifficulty: String = "Tümü"
    @Environment(\.presentationMode) var presentationMode
    
    // Oyun seçme fonksiyonu - ContentView'a oyunu iletmek için
    var gameSelected: (NSManagedObject) -> Void
    
    // Animasyon durumları
    @State private var cardOffset: [NSManagedObjectID: CGFloat] = [:]
    @State private var isAnimating = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var difficultyLevels = ["Tümü", "Kolay", "Orta", "Zor", "Uzman"]
    
    var filteredSavedGames: [SavedGame] {
        if selectedDifficulty == "Tümü" {
            return Array(savedGames)
        } else {
            return savedGames.filter { $0.difficulty == selectedDifficulty }
        }
    }
    
    // Boş durum görünümü
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "bookmark.slash.fill")
                .font(.system(size: 70))
                .foregroundColor(Color.blue.opacity(0.5))
            
            Text("Kaydedilmiş oyun bulunamadı")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(selectedDifficulty == "Tümü" ? 
                 "Henüz kaydedilmiş oyun bulunmamaktadır. Bir oyunu kaydetmek için oyun ekranında 'Kaydet' butonunu kullanın." : 
                 "\(selectedDifficulty) zorluk seviyesinde kaydedilmiş oyun bulunmamaktadır.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding()
    }
    
    var body: some View {
        ZStack {
            // Arka plan
            Color.darkModeBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Zorluk seviyesi filtreleme
                Picker("Zorluk", selection: $selectedDifficulty) {
                    ForEach(difficultyLevels, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                Text("Kaydedilmiş Oyunlar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textColor(for: colorScheme))
                    .padding(.top)
                
                if filteredSavedGames.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    // Kaydedilmiş oyunlar listesi - List kullanımı ile silme işlemi
                    List {
                        ForEach(filteredSavedGames, id: \.objectID) { game in
                            savedGameCard(for: game)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        // Onay sormadan direkt sil
                                        withAnimation {
                                            viewContext.delete(game)
                                            do {
                                                try viewContext.save()
                                            } catch {
                                                print("Error saving context: \(error)")
                                            }
                                        }
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .environment(\.defaultMinListRowHeight, 175)
                }
            }
        }
        // Bildirim yaklaşımı kullandığımız için burada bir şey yapmaya gerek yok
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Oyunu Sil"),
                message: Text("Bu kaydedilmiş oyunu silmek istediğinizden emin misiniz?"),
                primaryButton: .destructive(Text("Sil")) {
                    if let game = gameToDelete {
                        withAnimation {
                            viewContext.delete(game)
                            do {
                                try viewContext.save()
                                // Silinen oyunun offset değerini temizle
                                cardOffset.removeValue(forKey: game.objectID)
                            } catch {
                                print("Error saving context: \(error)")
                            }
                        }
                    }
                },
                secondaryButton: .cancel(Text("İptal")) {
                    // İptal edildiğinde kartı eski konumuna döndür
                    if let game = gameToDelete {
                        withAnimation {
                            cardOffset[game.objectID] = 0
                        }
                    }
                }
            )
        }
    }
    
    private func savedGameCard(for game: SavedGame) -> some View {
        let difficulty = game.difficulty ?? "Bilinmeyen"
        let dateCreated = game.dateCreated ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // Zorluk seviyesine göre renk
        let difficultyColor: Color = {
            switch difficulty {
            case "Kolay":
                return .green
            case "Orta":
                return .blue
            case "Zor":
                return .orange
            case "Uzman":
                return .red
            default:
                return .gray
            }
        }()
        
        return ZStack {
            // Arka plan rengi
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // Arka planda sil butonu (sürüklendiğinde görünen)
            HStack {
                Spacer()
                Image(systemName: "trash")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 100)
                    .background(Color.red)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Kart içeriği
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tarih")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(dateFormatter.string(from: dateCreated))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Zorluk")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(difficulty)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(difficultyColor.opacity(0.2))
                            .foregroundColor(difficultyColor)
                            .clipShape(Capsule())
                    }
                }
                
                Divider()
                
                HStack {
                    // Süre bilgisi
                    let elapsedTimeSeconds = Int(game.elapsedTime)
                    let minutes = elapsedTimeSeconds / 60
                    let seconds = elapsedTimeSeconds % 60
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Süre")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(String(format: "%02d:%02d", minutes, seconds))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Spacer()
                    
                    // Devam et butonu - direkt callback ile oyunu ContentView'a gönder
                    Button(action: {
                        // Animasyon ile yükleme göster
                        withAnimation {
                            isAnimating = true
                        }
                        
                        // Kısa bir gecikme ile callback'i çağır
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            // Callback'i çağırarak oyunu ilet
                            gameSelected(game)
                            
                            // Sayfayı kapat
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("Devam Et")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
            )
        }
        .frame(height: 160)
    }
}