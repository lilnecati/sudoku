//  TutorialView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI
import Combine

struct TutorialView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    // LocalizationManager'ı EnvironmentObject olarak değiştiriyoruz
    @EnvironmentObject var localizationManager: LocalizationManager
    
    // Dil değişikliğini doğrudan izlemek için AppStorage
    @AppStorage("app_language") private var appLanguage: String = "tr"
    
    // Genel durum değişkenleri
    @State private var currentStep = 0
    @State private var showPage = true
    @State private var refreshTrigger = UUID()
    
    // Arayüz metinleri için state'ler
    @State private var screenTitle: String = ""
    @State private var backButtonText: String = ""
    @State private var nextButtonText: String = ""
    @State private var completeButtonText: String = ""
    
    // Bildirim dinleyicileri için Set
    @State private var cancellables = Set<AnyCancellable>()
    
    // Basitleştirilmiş animasyon değişkenleri
    @State private var highlightScale: Bool = false
    
    // Görünümü yenileme için namespace
    @Namespace private var tutorialNamespace
    
    // Örnek Sudoku verileri
    private let singlePossibilityValues: [[Int]] = [
        [1, 2, 3],
        [5, 0, 6],  // Orta hücre "4" olabilir sadece
        [7, 8, 9]
    ]
    
    private let singleLocationNotes: [[[Int]]] = [
        [[1,2,3,4,6], [1,2,3,6,7], [2,3,4,6,8]],
        [[1,3,6,7,9], [2,3,4,6,8], [1,4,6,7,9]],
        [[1,2,3,4], [1,2,3,7,8], [3,4,7,8,9]]
    ]
    
    // Rehber adımları
    private var tutorialSteps: [TutorialStep] {
        [
            TutorialStep(
                titleKey: "tutorial_title_welcome",
                descriptionKey: "tutorial_desc_welcome",
                image: "sudoku.intro",
                tipKey: "tutorial_tip_welcome"
            ),
            TutorialStep(
                titleKey: "tutorial_title_game_rules",
                descriptionKey: "tutorial_desc_game_rules",
                image: "sudoku.rules",
                tipKey: "tutorial_tip_game_rules"
            ),
            TutorialStep(
                titleKey: "tutorial_title_cell_selection",
                descriptionKey: "tutorial_desc_cell_selection",
                image: "sudoku.input",
                tipKey: "tutorial_tip_cell_selection"
            ),
            TutorialStep(
                titleKey: "tutorial_title_notes_mode",
                descriptionKey: "tutorial_desc_notes_mode",
                image: "sudoku.notes",
                tipKey: "tutorial_tip_notes_mode"
            ),
            TutorialStep(
                titleKey: "tutorial_title_basic_strategies",
                descriptionKey: "tutorial_desc_basic_strategies",
                image: "sudoku.strategy1",
                tipKey: "tutorial_tip_basic_strategies"
            ),
            TutorialStep(
                titleKey: "tutorial_title_number_entry",
                descriptionKey: "tutorial_desc_number_entry",
                image: "sudoku.strategy2",
                tipKey: "tutorial_tip_number_entry"
            ),
            TutorialStep(
                titleKey: "tutorial_title_hints",
                descriptionKey: "tutorial_desc_hints",
                image: "sudoku.help",
                tipKey: "tutorial_tip_hints"
            ),
            TutorialStep(
                titleKey: "tutorial_title_completed",
                descriptionKey: "tutorial_desc_completed",
                image: "sudoku.ready",
                tipKey: "tutorial_tip_completed"
            )
        ]
    }
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Başlık ve kapat butonu
                HStack {
                    Text(screenTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                    
                    Spacer()
                    
                    Button {
                        SoundManager.shared.executeSound(.tap)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // İlerleme göstergesi
                HStack(spacing: 4) {
                    ForEach(0..<tutorialSteps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep >= index ? ColorManager.primaryBlue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentStep == index ? 1.1 : 1.0)
                    }
                }
                .padding(.top, 8)
                
                // Aktif adım içeriği - Basitleştirildi
                tutorialStepView(step: tutorialSteps[currentStep], stepNumber: currentStep + 1)
                    .id(refreshTrigger)  // Dil değiştiğinde içeriği zorla güncelle
                
                // Alt butonlar
                HStack(spacing: 20) {
                    // Geri butonu
                    Button {
                        SoundManager.shared.executeSound(.tap)
                        if currentStep > 0 {
                            changePage(to: currentStep - 1)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(backButtonText)
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            Color.blue
                        )
                        .cornerRadius(12)
                        .opacity(currentStep > 0 ? 1 : 0.5)
                    }
                    .disabled(currentStep == 0)
                    
                    // İleri/Bitir butonu
                    Button {
                        SoundManager.shared.executeSound(.tap)
                        if currentStep < tutorialSteps.count - 1 {
                            changePage(to: currentStep + 1)
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(currentStep == tutorialSteps.count - 1 ? completeButtonText : nextButtonText)
                            Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            currentStep == tutorialSteps.count - 1 ? Color.green : Color.blue
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            // İlk yüklemede tüm metinleri ayarla
            updateAllTexts()
            // Dil değişikliği için bildirim dinleyicilerini ayarla
            setupObservers()
        }
        .onDisappear {
            // Bildirim dinleyicilerini temizle
            cancellables.removeAll()
        }
        // AppStorage değişikliklerini izle - bu doğrudan UserDefaults değişikliklerini izler
        .onChange(of: appLanguage) { _, newLanguage in
            updateAllTexts()
            forceRefresh()
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }
    
    // Zorla UI yenileme
    private func forceRefresh() {
        refreshTrigger = UUID()
    }
    
    // Tüm metinleri güncelle
    private func updateAllTexts() {
        // Başlık ve butonları güncelle - UserDefaults'tan dil kodu kullanarak
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        // Başlık
        screenTitle = bundle?.localizedString(forKey: "How to Play", value: "How to Play", table: "Localizable") ?? "How to Play"
        
        // Buton metinleri
        backButtonText = bundle?.localizedString(forKey: "Back", value: "Back", table: "Localizable") ?? "Back"
        nextButtonText = bundle?.localizedString(forKey: "Next", value: "Next", table: "Localizable") ?? "Next"
        completeButtonText = bundle?.localizedString(forKey: "Complete", value: "Complete", table: "Localizable") ?? "Complete"
    }
    
    // Bildirim dinleyicileri kurulumu
    private func setupObservers() {
        // Doğrudan NotificationCenter kullanımı daha güvenilir olabilir
        NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))
            .sink { _ in
                // Dili doğrudan UserDefaults'tan oku
                if UserDefaults.standard.string(forKey: "app_language") != nil {
                    DispatchQueue.main.async {
                        updateAllTexts()
                        forceRefresh()
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: Notification.Name("AppLanguageChanged"))
            .sink { _ in
                // Dili doğrudan UserDefaults'tan oku
                if UserDefaults.standard.string(forKey: "app_language") != nil {
                    DispatchQueue.main.async {
                        updateAllTexts()
                        forceRefresh()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Sayfa geçişi için özel fonksiyon - basitleştirildi
    private func changePage(to newStep: Int) {
        currentStep = newStep
    }
    
    // Rehber adımı görünümü
    private func tutorialStepView(step: TutorialStep, stepNumber: Int) -> some View {
        // Doğrudan UserDefaults'tan dil kodu kullanarak çeviriyi al
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        let formattedStepText = String(format: bundle?.localizedString(forKey: "Step %d / %d", value: "Step %d / %d", table: "Localizable") ?? "Step %d / %d", stepNumber, tutorialSteps.count)
        
        // Metinleri daha güvenilir şekilde al
        let title = bundle?.localizedString(forKey: step.titleKey, value: step.titleKey, table: "Localizable") ?? step.titleKey
        let description = bundle?.localizedString(forKey: step.descriptionKey, value: step.descriptionKey, table: "Localizable") ?? step.descriptionKey
        let tip = bundle?.localizedString(forKey: step.tipKey, value: step.tipKey, table: "Localizable") ?? step.tipKey
        
        return ScrollView {
            VStack(spacing: 20) {
                // Adım numarası
                Text(formattedStepText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [ColorManager.primaryBlue, ColorManager.primaryBlue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                
                // Adım başlığı
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
                    .padding(.horizontal)
                
                // Görsel ve örnek icerik
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white,
                                    colorScheme == .dark ? Color(UIColor.secondarySystemBackground).opacity(0.95) : Color.white.opacity(0.95)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [ColorManager.primaryBlue.opacity(0.5), ColorManager.primaryBlue.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    VStack {
                        if stepNumber == 5 || stepNumber == 6 {
                            // Strateji örnekleri için mini Sudoku tablosu göster
                            tutorialExampleView(forStep: stepNumber)
                                .padding()
                        } else {
                            // Standart açıklama görünümü
                            VStack(spacing: 16) {
                                // İkon görünümü
                                getStepIcon(for: title)
                                    .font(.system(size: 60))
                                    .foregroundColor(getStepColor(for: title))
                                    .padding(.top, 10)
                                
                                // Açıklama metni
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: false))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.bottom, 10)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                        }
                    }
                }
                .frame(minHeight: 280)
                .padding(.horizontal)
                
                // İpucu bölümü
                if !tip.isEmpty {
                    VStack(spacing: 8) {
                        let tipTitle = bundle?.localizedString(forKey: "tutorial_tip_title", value: "TIP", table: "Localizable") ?? "TIP"
                        
                        Text(tipTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ColorManager.primaryOrange)
                        
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color(.systemGray5).opacity(0.5) : Color(.systemGray6).opacity(0.5))
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical)
        }
    }
    
    // Rehber adımı için ikon seçimi
    private func getStepIcon(for title: String) -> Image {
        if title.contains("Welcome") || title.contains("Bienvenue") || title.contains("Hoş Geldiniz") {
            return Image(systemName: "square.grid.3x3.fill")
        } else if title.contains("Game Rules") || title.contains("Règles") || title.contains("Kurallar") {
            return Image(systemName: "list.bullet")
        } else if title.contains("Cell") || title.contains("Cellule") || title.contains("Hücre") {
            return Image(systemName: "hand.tap.fill")
        } else if title.contains("Notes") || title.contains("Not") {
            return Image(systemName: "pencil")
        } else if title.contains("Hints") || title.contains("Indices") || title.contains("İpucu") {
            return Image(systemName: "lightbulb.fill")
        } else if title.contains("Completed") || title.contains("Félicitations") || title.contains("Tebrikler") {
            return Image(systemName: "checkmark.circle.fill")
        } else {
            return Image(systemName: "questionmark.circle.fill")
        }
    }
    
    // Rehber adımı için renk seçimi
    private func getStepColor(for title: String) -> Color {
        if title.contains("Welcome") || title.contains("Bienvenue") || title.contains("Hoş Geldiniz") {
            return ColorManager.primaryBlue
        } else if title.contains("Game Rules") || title.contains("Règles") || title.contains("Kurallar") {
            return ColorManager.primaryPurple
        } else if title.contains("Cell") || title.contains("Cellule") || title.contains("Hücre") {
            return ColorManager.primaryOrange
        } else if title.contains("Notes") || title.contains("Not") {
            return Color.blue
        } else if title.contains("Hints") || title.contains("Indices") || title.contains("İpucu") {
            return Color.yellow
        } else if title.contains("Completed") || title.contains("Félicitations") || title.contains("Tebrikler") {
            return ColorManager.primaryGreen
        } else {
            return Color.gray
        }
    }
    
    // Tek olasılık stratejisi örneği - basitleştirildi
    var singlePossibilityExample: some View {
        // Çevirileri doğrudan al
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        let exampleTitle = bundle?.localizedString(forKey: "Example: This cell can only contain 4", value: "Example: This cell can only contain 4", table: "Localizable") ?? "Example: This cell can only contain 4"
        let exampleDescription = bundle?.localizedString(forKey: "Due to other numbers in the row, column, and 3x3 block, only 4 can be placed in this cell.", value: "Due to other numbers in the row, column, and 3x3 block, only 4 can be placed in this cell.", table: "Localizable") ?? "Due to other numbers in the row, column, and 3x3 block, only 4 can be placed in this cell."
        
        return VStack(spacing: 12) {
            Text(exampleTitle)
                .font(.caption)
                .bold()
                .padding(.bottom, 5)
            
            // Mini 3x3 sudoku örneği - basitleştirildi
            VStack(spacing: 2) {
                ForEach(0..<3) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<3) { col in
                            let value = singlePossibilityValues[row][col]
                            let isHighlighted = row == 1 && col == 1
                            ZStack {
                                Rectangle()
                                    .fill(isHighlighted ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .border(Color.gray.opacity(0.3), width: 1)
                                
                                if isHighlighted {
                                    Text("?")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                } else if value > 0 {
                                    Text("\(value)")
                                        .font(.headline)
                                }
                            }
                            .overlay(
                                isHighlighted ? 
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.orange, lineWidth: 2) : nil
                            )
                        }
                    }
                }
            }
            
            Text(exampleDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
        }
    }
    
    // Tek konum stratejisi örneği - basitleştirildi
    var singleLocationExample: some View {
        // Çevirileri doğrudan al
        let path = Bundle.main.path(forResource: appLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        
        let exampleTitle = bundle?.localizedString(forKey: "Example: Number 5 can only be placed in this cell", value: "Example: Number 5 can only be placed in this cell", table: "Localizable") ?? "Example: Number 5 can only be placed in this cell"
        let exampleDescription = bundle?.localizedString(forKey: "In this region, 5 can only be placed in this cell because there's no room for 5 in other cells.", value: "In this region, 5 can only be placed in this cell because there's no room for 5 in other cells.", table: "Localizable") ?? "In this region, 5 can only be placed in this cell because there's no room for 5 in other cells."
        
        return VStack(spacing: 12) {
            Text(exampleTitle)
                .font(.caption)
                .bold()
                .padding(.bottom, 5)
            
            // Mini 3x3 sudoku örneği - basitleştirildi
            VStack(spacing: 2) {
                ForEach(0..<3) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<3) { col in
                            let cellNotes = singleLocationNotes[row][col]
                            let isHighlighted = row == 2 && col == 0
                            ZStack {
                                Rectangle()
                                    .fill(isHighlighted ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                    .border(Color.gray.opacity(0.3), width: 1)
                                
                                if isHighlighted {
                                    // Vurgulanmış hücrede 5 göster
                                    Text("5")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                } else if !cellNotes.isEmpty {
                                    // Not içeriği
                                    VStack(spacing: 1) {
                                        ForEach(0..<2) { noteRow in
                                            HStack(spacing: 1) {
                                                ForEach(0..<3) { noteCol in
                                                    let noteIndex = noteRow * 3 + noteCol
                                                    if noteIndex < cellNotes.count {
                                                        let note = cellNotes[noteIndex]
                                                        Text("\(note)")
                                                            .font(.system(size: 9))
                                                            .frame(width: 10, height: 10)
                                                    } else {
                                                        Spacer()
                                                            .frame(width: 10, height: 10)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .overlay(
                                isHighlighted ? 
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.green, lineWidth: 2) : nil
                            )
                        }
                    }
                }
            }
            
            Text(exampleDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
        }
    }
    
    // Örnek strateji görünümleri
    func tutorialExampleView(forStep step: Int) -> some View {
        // Tek Olasılık Stratejisi adımı 5, Tek Konum Stratejisi adımı 6
        return Group {
            if step == 5 {
                singlePossibilityExample
            } else if step == 6 {
                singleLocationExample
            } else {
                let noExampleText = Bundle.main.path(forResource: appLanguage, ofType: "lproj").flatMap {
                    Bundle(path: $0)?.localizedString(forKey: "Example Not Available", value: "Example Not Available", table: "Localizable")
                } ?? "Example Not Available"
                
                Text(noExampleText)
            }
        }
    }
}

// Rehber adımı modeli
struct TutorialStep {
    let titleKey: String
    let descriptionKey: String
    let image: String
    let tipKey: String
}

// Preview
struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView()
    }
}
