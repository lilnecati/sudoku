import SwiftUI
import Combine

// Öğretici adımları - genişletilmiş versiyon
enum GameTutorialStep: Int, CaseIterable, Identifiable {
    // Temel adımlar
    case welcome = 0
    case gameRules
    case cellSelection
    case numberEntry
    case conflictDetection
    case notesMode
    case advancedNotes
    case basicStrategies
    case hints
    case savingProgress
    case statistics
    case practice
    case completed
    
    // Identifiable için id
    var id: Int { self.rawValue }
    
    // Adım başlığı
    var title: String {
        let key: String
        switch self {
        case .welcome:
            key = "tutorial_title_welcome"
        case .gameRules:
            key = "tutorial_title_game_rules"
        case .cellSelection:
            key = "tutorial_title_cell_selection"
        case .numberEntry:
            key = "tutorial_title_number_entry"
        case .conflictDetection:
            key = "tutorial_title_conflict_detection"
        case .notesMode:
            key = "tutorial_title_notes_mode"
        case .advancedNotes:
            key = "tutorial_title_advanced_notes"
        case .basicStrategies:
            key = "tutorial_title_basic_strategies"
        case .hints:
            key = "tutorial_title_hints"
        case .savingProgress:
            key = "tutorial_title_saving_progress"
        case .statistics:
            key = "tutorial_title_statistics"
        case .practice:
            key = "tutorial_title_practice"
        case .completed:
            key = "tutorial_title_completed"
        }
        return NSLocalizedString(key, comment: "")
    }
    
    // Adım açıklaması - detaylı
    var description: String {
        let key: String
        switch self {
        case .welcome:
            key = "tutorial_desc_welcome"
        case .gameRules:
            key = "tutorial_desc_game_rules"
        case .cellSelection:
            key = "tutorial_desc_cell_selection"
        case .numberEntry:
            key = "tutorial_desc_number_entry"
        case .conflictDetection:
            key = "tutorial_desc_conflict_detection"
        case .notesMode:
            key = "tutorial_desc_notes_mode"
        case .advancedNotes:
            key = "tutorial_desc_advanced_notes"
        case .basicStrategies:
            key = "tutorial_desc_basic_strategies"
        case .hints:
            key = "tutorial_desc_hints"
        case .savingProgress:
            key = "tutorial_desc_saving_progress"
        case .statistics:
            key = "tutorial_desc_statistics"
        case .practice:
            key = "tutorial_desc_practice"
        case .completed:
            key = "tutorial_desc_completed"
        }
        return NSLocalizedString(key, comment: "")
    }
    
    // Vurgulanacak hedef bileşen
    var highlightTarget: String {
        switch self {
        case .welcome, .gameRules, .basicStrategies, .completed:
            return ""  // Genel vurgulama yok
        case .cellSelection, .conflictDetection:
            return "board"  // Tahta vurgulanacak
        case .numberEntry:
            return "numberPad"  // Numara tuşları vurgulanacak
        case .notesMode, .advancedNotes:
            return "notesButton"  // Not modu butonu vurgulanacak
        case .hints:
            return "hintButton"  // İpucu butonu vurgulanacak
        case .savingProgress:
            return "saveButton"  // Kaydetme butonu vurgulanacak
        case .statistics:
            return "statsButton"  // İstatistik butonu vurgulanacak
        case .practice:
            return "interactionArea"  // Etkileşim alanı vurgulanacak
        }
    }
    
    // Bu adım için interaktif pratik gerekiyor mu?
    var requiresInteraction: Bool {
        return self == .practice || self == .cellSelection || self == .numberEntry || self == .notesMode
    }
    
    // Bu adım için animasyon tipi
    var animationType: TutorialAnimationType {
        switch self {
        case .welcome, .gameRules, .completed:
            return .fade
        case .cellSelection, .hints:
            return .bounce
        case .numberEntry, .conflictDetection, .practice:
            return .pulse
        case .notesMode, .advancedNotes:
            return .highlight
        case .basicStrategies, .savingProgress, .statistics:
            return .slide
        }
    }
}

// Öğretici animasyon tipleri
enum TutorialAnimationType {
    case fade     // Yavaşça belirme/solma
    case bounce   // Zıplama efekti
    case pulse    // Nabız gibi büyüme/küçülme
    case highlight // Parlama efekti
    case slide    // Kayma hareketi
}

class TutorialManager: ObservableObject {
    // Singleton örneği
    static let shared = TutorialManager()
    
    // Öğretici durumu
    @Published var isActive: Bool = false
    @Published var currentStep: GameTutorialStep = .welcome
    @Published var hasCompletedTutorial: Bool = false
    
    // İnteraktif tamamlama takibi - adım tamamlama durumları
    @Published var completedInteractions: Set<GameTutorialStep> = []
    @Published var currentInteractionRequired: Bool = false
    
    // Adım tamamlama animasyonu
    @Published var showCompletionAnimation: Bool = false
    
    // Kullanıcı tercihleri
    @AppStorage("hasSeenTutorial") var hasSeenTutorial: Bool = false
    @AppStorage("showTutorialTips") var showTutorialTips: Bool = true
    
    // İçerik kontrolü
    @Published var shouldBlockInteraction: Bool = false
    
    // İlerleme kaydetme
    @AppStorage("lastTutorialStep") var lastTutorialStep: Int = 0
    
    // Tipini değiştirme
    private var cancellables = Set<AnyCancellable>()
    
    // Kullanıcı etkileşim geri çağrısı
    var onUserInteractionNeeded: ((GameTutorialStep) -> Void)? = nil
    
    init() {
        // Durumu AppStorage'dan yükle
        hasCompletedTutorial = hasSeenTutorial
        if let savedStep = GameTutorialStep(rawValue: lastTutorialStep) {
            currentStep = savedStep
        }
        
        // Adım değişimini izle
        $currentStep
            .sink { [weak self] step in
                guard let self = self else { return }
                
                // İlerleme kaydet
                self.lastTutorialStep = step.rawValue
                
                // İnteraktif adım ayarla
                self.currentInteractionRequired = step.requiresInteraction
                
                // Tamamlama kontrolü
                if step == .completed {
                    self.hasSeenTutorial = true
                    self.hasCompletedTutorial = true
                    
                    // Son adımdan sonra rehberi otomatik kapat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.isActive = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Rehberi başlat
    func startTutorial() {
        // Eğer daha önce yarım kalmış bir ilerleme varsa oradan devam et
        if !hasCompletedTutorial && lastTutorialStep > 0 {
            if let savedStep = GameTutorialStep(rawValue: lastTutorialStep) {
                currentStep = savedStep
            } else {
                currentStep = .welcome
            }
        } else {
            currentStep = .welcome
        }
        
        withAnimation(.easeIn(duration: 0.5)) {
            isActive = true
        }
    }
    
    // Rehberi durdur
    func stopTutorial() {
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
    }
    
    // Rehbere devam et
    func resumeTutorial() {
        withAnimation(.easeIn(duration: 0.3)) {
            isActive = true
        }
    }
    
    // Rehberi sıfırla
    func resetTutorial() {
        currentStep = .welcome
        completedInteractions.removeAll()
        lastTutorialStep = 0
        hasCompletedTutorial = false
        hasSeenTutorial = false
    }
    
    // Sonraki adıma geç
    func nextStep() {
        // İnteraktif adımın tamamlandığından emin ol
        if currentStep.requiresInteraction && !completedInteractions.contains(currentStep) {
            // Kullanıcıya bildir
            showInteractionPrompt()
            return
        }
        
        if let nextIndex = GameTutorialStep.allCases.firstIndex(where: { $0 == currentStep })?.advanced(by: 1),
           nextIndex < GameTutorialStep.allCases.count {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStep = GameTutorialStep.allCases[nextIndex]
            }
        }
    }
    
    // Önceki adıma dön
    func previousStep() {
        if let prevIndex = GameTutorialStep.allCases.firstIndex(where: { $0 == currentStep })?.advanced(by: -1),
           prevIndex >= 0 {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStep = GameTutorialStep.allCases[prevIndex]
            }
        }
    }
    
    // Belirli bir adıma git
    func goToStep(_ step: GameTutorialStep) {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentStep = step
        }
    }
    
    // İnteraktif tamamlama işle
    func completeInteraction(for step: GameTutorialStep) {
        guard step.requiresInteraction else { return }
        
        completedInteractions.insert(step)
        
        // Tamamlama animasyonu göster
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCompletionAnimation = true
        }
        
        // Animasyonu sıfırla
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                self.showCompletionAnimation = false
            }
        }
    }
    
    // Etkileşim uyarısı göster
    private func showInteractionPrompt() {
        // Kullanıcı etkileşimi için geri çağrı
        onUserInteractionNeeded?(currentStep)
        
        // Animasyon uyarısı
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            shouldBlockInteraction = true
        }
        
        // Animasyonu sıfırla
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.shouldBlockInteraction = false
            }
        }
    }
    
    // İlerleme durumu (yüzde olarak)
    var progressPercentage: Double {
        guard let currentIndex = GameTutorialStep.allCases.firstIndex(of: currentStep) else { return 0 }
        let totalSteps = GameTutorialStep.allCases.count - 1 // son adım olan .completed hariç
        return Double(currentIndex) / Double(totalSteps)
    }
    
    // Yaklaşık tamamlama yüzdesi
    var progressText: String {
        guard let currentIndex = GameTutorialStep.allCases.firstIndex(of: currentStep),
              currentStep != .completed else { return "Tamamlandı" }
        
        let totalSteps = GameTutorialStep.allCases.count - 1 // .completed hariç
        let percentage = Int((Double(currentIndex) / Double(totalSteps)) * 100.0)
        return "%\(percentage)"
    }
    
    // İpucu metinleri al
    func getTipForStep(_ step: GameTutorialStep) -> String {
        let key: String
        switch step {
        case .cellSelection:
            key = "tutorial_tip_cell_selection"
        case .numberEntry:
            key = "tutorial_tip_number_entry"
        case .notesMode:
            key = "tutorial_tip_notes_mode"
        case .basicStrategies:
            key = "tutorial_tip_basic_strategies"
        case .hints:
            key = "tutorial_tip_hints"
        default:
            return ""
        }
        return NSLocalizedString(key, comment: "")
    }
}
