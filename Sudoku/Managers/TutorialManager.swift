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
        switch self {
        case .welcome:
            return "Sudoku'ya Hoş Geldiniz!"
        case .gameRules:
            return "Oyun Kuralları"
        case .cellSelection:
            return "Hücre Seçimi"
        case .numberEntry:
            return "Sayı Girişi"
        case .conflictDetection:
            return "Çakışma Tespiti"
        case .notesMode:
            return "Not Alma Modu"
        case .advancedNotes:
            return "Gelişmiş Notlar"
        case .basicStrategies:
            return "Temel Stratejiler"
        case .hints:
            return "İpuçları Sistemi"
        case .savingProgress:
            return "İlerleme Kaydetme"
        case .statistics:
            return "İstatistikler"
        case .practice:
            return "Pratik Yapalım"
        case .completed:
            return "Tebrikler!"
        }
    }
    
    // Adım açıklaması - detaylı
    var description: String {
        switch self {
        case .welcome:
            return "Bu interaktif rehberde Sudoku'nun temel özelliklerini ve stratejilerini öğreneceksiniz. Her adımda pratik yapma şansınız olacak. İlerlemek için 'İleri' butonuna dokunun."
        case .gameRules:
            return "Sudoku, 9x9 bir ızgarada oynanır. Amaç, her satır, sütun ve 3x3 bloğun 1'den 9'a kadar rakamları tam olarak bir kez içermesini sağlamaktır. Başlangıçta bazı hücreler doldurulmuştur ve bu ipuçlarını kullanarak tahtayı tamamlarsınız."
        case .cellSelection:
            return "Değer girmek istediğiniz boş bir hücreye dokunun. Seçili hücre mavi renkte vurgulanacaktır. Aynı hücreye tekrar dokunarak seçimi kaldırabilirsiniz. Hücreye dokunduğunuzda hafif bir titreşim hissedeceksiniz."
        case .numberEntry:
            return "Seçili hücreye değer girmek için alttaki sayı tuşlarından birine dokunun. Rakamlar sadece boş hücrelere ve ipucu olmayan hücrelere girilebilir. Girdiğiniz sayının tahtadaki kuralları ihlal edip etmediği otomatik olarak kontrol edilir."
        case .conflictDetection:
            return "Bir hücreye değer girdiğinizde, bu değer aynı satır, sütun veya 3x3 bloktaki diğer hücrelerle çakışıyorsa, çakışan hücreler kırmızı ile işaretlenir. Geçerli bir hamle yapmak için çakışmaları düzeltmeniz gerekir."
        case .notesMode:
            return "Emin olmadığınız rakamları not olarak girmek için 'Not Modu' butonunu kullanın. Not modundayken, bir hücreye birden fazla olası değer kaydedebilirsiniz. Bu mod, karmaşık bulmacalarda çok yardımcı olur."
        case .advancedNotes:
            return "Notlar, hücrelere tek tek değer girmeden önce olası değerleri takip etmenize yardımcı olur. 'Notları Güncelle' seçeneği, mevcut tahta durumuna göre tüm notları otomatik olarak günceller ve geçersiz olasılıkları kaldırır."
        case .basicStrategies:
            return "Tek Olasılık: Bir hücre için sadece bir olası değer varsa, o değeri girin.\nTek Hücre: Bir değer bir satır, sütun veya blokta sadece bir hücreye yerleştirilebiliyorsa, o değeri o hücreye girin.\nKesişim: Bir değer bir satır veya sütunda sadece belirli bir blokta olabiliyorsa, diğer olasılıkları eleyin."
        case .hints:
            return "Bir ipucu almak için 'İpucu' butonunu kullanabilirsiniz. İpucu sistemi, tahtadaki en mantıklı bir sonraki hamleyi vurgular veya direkt olarak bir hücreyi doldurabilir. Her zorluk seviyesinde sınırlı sayıda ipucu hakkınız vardır."
        case .savingProgress:
            return "Oyun otomatik olarak ilerlemenizi kaydeder. İstediğiniz zaman ara verebilir ve daha sonra kaldığınız yerden devam edebilirsiniz. 'Kaydet ve Çık' butonunu kullanarak mevcut oyunu açıkça kaydedebilirsiniz."
        case .statistics:
            return "Oyun istatistikleriniz her oyundan sonra kaydedilir. En iyi sürelerinizi, çözülen bulmaca sayısını ve ortalama çözüm sürenizi 'İstatistikler' ekranından görebilirsiniz. Bu veriler zorluk seviyesine göre sınıflandırılır."
        case .practice:
            return "Şimdi öğrendiklerinizi pratik etme zamanı! Bir sonraki adıma geçmeden önce bir boş hücre seçin, bir değer girin ve not alın. Uygulamalı öğrenme en etkili yöntemdir. Hemen deneyin!"
        case .completed:
            return "Tebrikler! Sudoku'nun temel ve ileri özelliklerini öğrendiniz. Artık kendi başınıza oynamaya hazırsınız. Farklı zorluk seviyelerini deneyin ve becerilerinizi geliştirin. İyi oyunlar!"
        }
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
        switch step {
        case .cellSelection:
            return "İpucu: Tahtayı çift dokunarak tüm benzer değerleri vurgulayabilirsiniz."
        case .numberEntry:
            return "İpucu: Aynı sayıya tekrar dokunarak girdiğiniz değeri silebilirsiniz."
        case .notesMode:
            return "İpucu: Kalem işaretleri, olası değerleri takip etmenize yardımcı olur."
        case .basicStrategies:
            return "İpucu: Bir satır, sütun veya bloktaki diğer hücrelere bakarak olasılıkları daraltın."
        case .hints:
            return "İpucu: İpuçlarını stratejik olarak kullanın, zorlandığınız noktalarda yardımcı olacaktır."
        default:
            return ""
        }
    }
}
