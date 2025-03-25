import SwiftUI
import Combine

// Öğretici adımları
enum GameTutorialStep: Int, CaseIterable {
    case welcome = 0
    case cellSelection
    case numberEntry
    case notesMode
    case hints
    case completed
    
    var title: String {
        switch self {
        case .welcome:
            return "Sudoku'ya Hoş Geldiniz!"
        case .cellSelection:
            return "Hücre Seçimi"
        case .numberEntry:
            return "Sayı Girişi"
        case .notesMode:
            return "Not Alma Modu"
        case .hints:
            return "İpuçları"
        case .completed:
            return "Hazırsınız!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Bu kısa rehberde Sudoku'nun temel özelliklerini öğreneceksiniz. İlerlemek için 'İleri' butonuna dokunun."
        case .cellSelection:
            return "Değer girmek istediğiniz boş bir hücreye dokunun. Seçili hücre mavi renkte görünecektir."
        case .numberEntry:
            return "Seçili hücreye değer girmek için alttaki sayı tuşlarından birine dokunun. Rakamlar boş hücrelere girilir."
        case .notesMode:
            return "Emin olmadığınız rakamları not olarak girmek için 'Not Modu' butonunu kullanın. Bu mod, ihtimalleri not almanıza yardımcı olur."
        case .hints:
            return "Bir ipucu almak için 'İpucu' butonunu kullanabilirsiniz. Her oyunda sınırlı sayıda ipucu hakkınız olduğunu unutmayın."
        case .completed:
            return "Tebrikler! Artık Sudoku oynamaya hazırsınız. İyi oyunlar!"
        }
    }
    
    var highlightTarget: String {
        switch self {
        case .welcome:
            return ""
        case .cellSelection:
            return "board"
        case .numberEntry:
            return "numberPad"
        case .notesMode:
            return "notesButton"
        case .hints:
            return "hintButton"
        case .completed:
            return ""
        }
    }
}

class TutorialManager: ObservableObject {
    // Öğretici durumu
    @Published var isActive: Bool = false
    @Published var currentStep: GameTutorialStep = .welcome
    @Published var hasCompletedTutorial: Bool = false
    
    // İlk kez başlatma için
    @AppStorage("hasSeenTutorial") var hasSeenTutorial: Bool = false
    
    // Tipini değiştirme
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Durumu AppStorage'dan yükle
        hasCompletedTutorial = hasSeenTutorial
        
        // Rehber tamamlandığında AppStorage'a kaydet
        $currentStep
            .sink { [weak self] step in
                if step == .completed {
                    self?.hasSeenTutorial = true
                    self?.hasCompletedTutorial = true
                    
                    // Son adımdan sonra rehberi otomatik kapat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.isActive = false
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Rehberi başlat
    func startTutorial() {
        currentStep = .welcome
        isActive = true
    }
    
    // Rehberi durdur
    func stopTutorial() {
        isActive = false
    }
    
    // Sonraki adıma geç
    func nextStep() {
        if let nextIndex = GameTutorialStep.allCases.firstIndex(where: { $0 == currentStep })?.advanced(by: 1),
           nextIndex < GameTutorialStep.allCases.count {
            currentStep = GameTutorialStep.allCases[nextIndex]
        }
    }
    
    // Önceki adıma dön
    func previousStep() {
        if let prevIndex = GameTutorialStep.allCases.firstIndex(where: { $0 == currentStep })?.advanced(by: -1),
           prevIndex >= 0 {
            currentStep = GameTutorialStep.allCases[prevIndex]
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
}
