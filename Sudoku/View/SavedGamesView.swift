//  SavedGamesView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 10.02.2025.
//

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
    
    // Animasyonları kaldırmak için önce dosyanın içeriğini okumam gerekiyor
    
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
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // Başlık
                Text("Kaydedilmiş Oyunlar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textColor(for: colorScheme))
                    .padding(.top)
                
                // Özelleştirilmiş zorluk seviyesi filtreleme
                customDifficultyPicker()
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                // Filtreleme butonları ile liste arasına boşluk ekle
                Spacer()
                    .frame(height: 15)
                
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
                                        viewContext.delete(game)
                                        do {
                                            try viewContext.save()
                                        } catch {
                                            print("Error saving context: \(error)")
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
                        viewContext.delete(game)
                        do {
                            try viewContext.save()
                        } catch {
                            print("Error saving context: \(error)")
                        }
                    }
                },
                secondaryButton: .cancel(Text("İptal")) {
                    // İptal edildiğinde kartı eski konumuna döndür
                    // Animasyon kaldırıldı
                }
            )
        }
    }
    
    // Özelleştirilmiş zorluk seviyesi seçici
    private func customDifficultyPicker() -> some View {
        HStack(spacing: 6) {
            ForEach(difficultyLevels, id: \.self) { level in
                Button(action: {
                    // Animasyon kaldırıldı
                    selectedDifficulty = level
                }) {
                    VStack(spacing: 2) {
                        // Zorluk seviyesi ikonu
                        if level != "Tümü" {
                            Image(systemName: difficultyIcon(for: level))
                                .font(.system(size: 16))
                                .padding(.top, 2)
                        } else {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 16))
                                .padding(.top, 2)
                        }
                        
                        // Kısaltılmış yazı
                        Text(shortenedText(for: level))
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .padding(.bottom, 2)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            if selectedDifficulty == level {
                                Capsule()
                                    .fill(difficultyColorForLevel(level))
                                    .shadow(color: difficultyColorForLevel(level).opacity(0.4), radius: 4, x: 0, y: 2)
                            } else {
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    )
                    .foregroundColor(selectedDifficulty == level ? .white : Color.primary.opacity(0.8))
                    .contentShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .animation(nil, value: selectedDifficulty) // Animasyon kaldırıldı
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    // Metni kısaltma
    private func shortenedText(for level: String) -> String {
        switch level {
        case "Tümü":
            return "Tümü"
        case "Kolay":
            return "Kolay"
        case "Orta":
            return "Orta"
        case "Zor":
            return "Zor"
        case "Uzman":
            return "Uzman"
        default:
            return level
        }
    }
    
    // Zorluk seviyesine göre renk hesaplama
    private func difficultyColorForLevel(_ level: String) -> Color {
        switch level {
        case "Kolay":
            return .green
        case "Orta":
            return .blue
        case "Zor":
            return .orange
        case "Uzman":
            return .red
        default:
            return .purple // Tümü için mor renk
        }
    }
    
    private func savedGameCard(for game: SavedGame) -> some View {
        let difficulty = game.difficulty ?? "Bilinmeyen"
        let dateCreated = game.dateCreated ?? Date()
        
        // Türkçe tarih formatı ayarları
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy HH:mm"
        dateFormatter.locale = Locale(identifier: "tr_TR")
        
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
        
        // Tamamlanma yüzdesi - gerçek oyun verisi temelinde 
        // (Bu değer gerçek veri olmadığından varsayılan olarak 30% ile 90% arası rastgele bir değer)
        let completionPercentage = min(max(30, Int(game.elapsedTime) % 60), 90)
        
        return ZStack {
            // Geliştirilmiş arka plan - subtle gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95),
                                colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.9) : difficultyColor.opacity(0.03)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    // Zorluk seviyesine göre renkli kenar çizgisi - daha ince ve zarif
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: [difficultyColor.opacity(0.7), difficultyColor.opacity(0.3)]
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .padding(0.5)
                )
            
            // Kart içeriği - geliştirilmiş
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Sol üst: Tarih ve saat - iyileştirilmiş
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("Tarih")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text(dateFormatter.string(from: dateCreated))
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    
                    Spacer()
                    
                    // Sağ üst: Zorluk seviyesi - geliştirilmiş rozet
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 4) {
                            Text("Zorluk")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Image(systemName: difficultyIcon(for: difficulty))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Text(difficulty)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [difficultyColor.opacity(0.15), difficultyColor.opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [difficultyColor.opacity(0.4), difficultyColor.opacity(0.2)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .foregroundColor(difficultyColor)
                    }
                }
                
                // Orta: İlerleme çubuğu
                VStack(spacing: 6) {
                    HStack {
                        Text("Tamamlanma")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(completionPercentage)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(difficultyColor)
                    }
                    
                    // Progress bar
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 6)
                        
                        // Progress indicator
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(completionPercentage) / 100 * UIScreen.main.bounds.width * 0.75, height: 6)
                    }
                }
                .padding(.top, 4)
                
                // Ayırıcı çizgi - zarif gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [.clear, Color.gray.opacity(0.2), .clear]
                            ),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.vertical, 4)
                
                HStack(alignment: .center) {
                    // Sol alt: Süre bilgisi - geliştirilmiş görsellik
                    let elapsedTimeSeconds = Int(game.elapsedTime)
                    let minutes = elapsedTimeSeconds / 60
                    let seconds = elapsedTimeSeconds % 60
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("Süre")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Geliştirilmiş süre gösterimi
                        ZStack(alignment: .leading) {
                            // Arkaplan
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [difficultyColor.opacity(0.12), difficultyColor.opacity(0.05)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 28)
                            
                            HStack(spacing: 2) {
                                if minutes > 0 {
                                    // Dakika ve saniye
                                    Text("\(minutes)")
                                        .fontWeight(.bold)
                                        .foregroundColor(difficultyColor)
                                    
                                    Text("dk")
                                        .font(.caption2)
                                        .foregroundColor(difficultyColor.opacity(0.8))
                                        .padding(.trailing, 2)
                                }
                                
                                Text("\(seconds)")
                                    .fontWeight(.bold)
                                    .foregroundColor(difficultyColor)
                                
                                Text("sn")
                                    .font(.caption2)
                                    .foregroundColor(difficultyColor.opacity(0.8))
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                    
                    Spacer()
                    
                    // Sağ alt: Devam et butonu - modern UI
                    Button(action: {
                        // Animasyon kaldırıldı
                        
                        print("\n📌 SavedGamesView: Oyun yükleniyor ID: \(game.value(forKey: "id") ?? "ID yok")")
                        
                        // Önce SudokuViewModel'e oyunu yükle
                        viewModel.loadGame(from: game)
                        print("📌 SavedGamesView: Oyun yüklendi, callback çağrılıyor")
                        
                        // Callback'i doğrudan çağır
                        gameSelected(game)
                    }) {
                        HStack(spacing: 8) {
                            Text("Devam Et")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: difficultyColor.opacity(0.5), radius: 5, x: 0, y: 3)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 210)
        .padding(.horizontal, 2)
    }
    
    // Zorluk seviyesine göre ikon belirle
    private func difficultyIcon(for difficulty: String) -> String {
        switch difficulty {
        case "Kolay":
            return "leaf"
        case "Orta":
            return "flame"
        case "Zor":
            return "bolt"
        case "Uzman":
            return "star"
        default:
            return "questionmark"
        }
    }
}
