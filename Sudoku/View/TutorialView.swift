//  TutorialView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI

struct TutorialView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var currentStep = 0
    
    // Animasyon durum değişkenleri
    @State private var animationProgress: Double = 0.5
    @State private var highlightScale: Bool = false
    @State private var animateInputValue: Bool = true
    @State private var inputAnimationValue: Int = 5
    @State private var animateNote: Bool = false
    @State private var lastAddedNote: Int = 0
    @State private var notesSet: Set<Int> = []
    
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
    private let tutorialSteps = [
        TutorialStep(
            title: "Sudoku'ya Hoş Geldiniz",
            description: "Sudoku, 9x9'luk bir tabloda sayıları yerleştirdiğiniz bir bulmaca oyunudur. Bu rehber size temel kuralları ve stratejileri öğretecek.",
            image: "sudoku.intro",
            tip: "Ekranı kaydırarak diğer adımlara geçebilirsiniz."
        ),
        TutorialStep(
            title: "Temel Kurallar",
            description: "Her satır, her sütun ve her 3x3'lük bölge 1'den 9'a kadar olan sayıları içermelidir. Hiçbir sayı tekrarlanmamalıdır.",
            image: "sudoku.rules",
            tip: "Başlangıçta verilen sayılar değiştirilemez ve ipucu olarak kullanılır."
        ),
        TutorialStep(
            title: "Sayı Girişi",
            description: "Boş bir hücreye dokunarak seçin, ardından alt kısımdaki sayı tuşlarını kullanarak değer girin.",
            image: "sudoku.input",
            tip: "Bir sayıya uzun basarak o sayıyı not olarak ekleyebilirsiniz."
        ),
        TutorialStep(
            title: "Notlar",
            description: "Emin olmadığınız hücrelere not alabilirsiniz. Notlar, o hücreye girebileceğiniz olası değerleri hatırlamanıza yardımcı olur.",
            image: "sudoku.notes",
            tip: "Notlar, bir hücreye kesin karar vermeden önce olasılıkları takip etmenizi sağlar."
        ),
        TutorialStep(
            title: "Tek Olasılık Stratejisi",
            description: "Bir hücreye yalnızca bir sayı girilebiliyorsa, o sayıyı girin. Satır, sütun ve 3x3 bölgesindeki diğer sayıları kontrol edin.",
            image: "sudoku.strategy1",
            tip: "Bu en temel Sudoku stratejisidir ve çoğu kolay bulmacayı çözmenizi sağlar."
        ),
        TutorialStep(
            title: "Tek Konum Stratejisi",
            description: "Bir satır, sütun veya 3x3 bölgesinde bir sayı yalnızca bir hücreye yerleştirilebiliyorsa, o sayıyı oraya yerleştirin.",
            image: "sudoku.strategy2",
            tip: "Diğer hücrelerdeki notları kontrol ederek bu stratejiyi uygulayabilirsiniz."
        ),
        TutorialStep(
            title: "İpuçları ve Yardım",
            description: "Zorlandığınızda ipucu alabilir veya hatalı girişlerinizi kontrol edebilirsiniz.",
            image: "sudoku.help",
            tip: "Oyun sırasında '?' düğmesine basarak bu rehbere tekrar ulaşabilirsiniz."
        ),
        TutorialStep(
            title: "Hazırsınız!",
            description: "Artık Sudoku oynamaya hazırsınız. Kolay seviyeden başlayarak deneyim kazanın ve zamanla daha zor seviyelere geçin.",
            image: "sudoku.ready",
            tip: "Düzenli pratik yaparak Sudoku becerilerinizi geliştirebilirsiniz. İyi eğlenceler!"
        )
    ]
    
    var body: some View {
        ZStack {
            // Modern gradient arka plan
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color(.systemGray6) : .white,
                    colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Başlık ve kapat butonu
                HStack {
                    Text("Nasıl Oynanır")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                    
                    Spacer()
                    
                    Button(action: {
                        SoundManager.shared.executeSound(.tap)
                        presentationMode.wrappedValue.dismiss()
                    }) {
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
                            .scaleEffect(currentStep == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    }
                }
                .padding(.top, 8)
                
                // Rehber içeriği
                TabView(selection: $currentStep) {
                    ForEach(0..<tutorialSteps.count, id: \.self) { index in
                        tutorialStepView(step: tutorialSteps[index], stepNumber: index + 1)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                .transition(.slide)
                
                // Alt butonlar
                HStack(spacing: 20) {
                    // Geri butonu
                    Button(action: {
                        SoundManager.shared.executeSound(.tap)
                        if currentStep > 0 {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Geri")
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [ColorManager.primaryBlue, ColorManager.primaryBlue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ColorManager.primaryBlue.opacity(0.4), radius: 4, x: 0, y: 3)
                        .opacity(currentStep > 0 ? 1 : 0.5)
                    }
                    .disabled(currentStep == 0)
                    
                    // İleri/Bitir butonu
                    Button(action: {
                        SoundManager.shared.executeSound(.tap)
                        if currentStep < tutorialSteps.count - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack {
                            Text(currentStep == tutorialSteps.count - 1 ? "Tamamla" : "İleri")
                            Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                        }
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    currentStep == tutorialSteps.count - 1 ? ColorManager.primaryGreen : ColorManager.primaryBlue,
                                    currentStep == tutorialSteps.count - 1 ? ColorManager.primaryGreen.opacity(0.8) : ColorManager.primaryBlue.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: (currentStep == tutorialSteps.count - 1 ? ColorManager.primaryGreen : ColorManager.primaryBlue).opacity(0.4), radius: 4, x: 0, y: 3)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // Rehber adımı görünümü
    private func tutorialStepView(step: TutorialStep, stepNumber: Int) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Adım numarası
                Text("Adım \(stepNumber) / \(tutorialSteps.count)")
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
                    .transition(.scale.combined(with: .opacity))
                
                // Adım başlığı
                Text(step.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                
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
                    
                    if step.title.contains("Tek Olasılık") || step.title.contains("Tek Konum") {
                        // Strateji örnekleri için mini Sudoku tablosu göster
                        tutorialExampleView(forStep: stepNumber)
                            .padding()
                    } else {
                        // Standart açıklama görünümü
                        VStack(spacing: 16) {
                            // İkon görünümü
                            getStepIcon(for: step.title)
                                .font(.system(size: 60))
                                .foregroundColor(getStepColor(for: step.title))
                                .padding(.top, 10)
                            
                            // Açıklama metni
                            Text(step.description)
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
                .frame(height: 280)
                .padding(.horizontal)
                
                // İpucu bölümü
                VStack(spacing: 8) {
                    Text("İPUCU")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(ColorManager.primaryOrange)
                    
                    Text(step.tip)
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
            .padding(.vertical)
        }
    }
    
    // Rehber adımı için ikon seçimi
    private func getStepIcon(for title: String) -> Image {
        switch true {
        case title.contains("Hoş Geldiniz"):
            return Image(systemName: "square.grid.3x3.fill")
        case title.contains("Temel Kurallar"):
            return Image(systemName: "list.bullet")
        case title.contains("Sayı Girişi"):
            return Image(systemName: "hand.tap.fill")
        case title.contains("Notlar"):
            return Image(systemName: "pencil")
        case title.contains("İpuçları"):
            return Image(systemName: "lightbulb.fill")
        case title.contains("Hazırsınız"):
            return Image(systemName: "checkmark.circle.fill")
        default:
            return Image(systemName: "questionmark.circle.fill")
        }
    }
    
    // Rehber adımı için renk seçimi
    private func getStepColor(for title: String) -> Color {
        switch true {
        case title.contains("Hoş Geldiniz"):
            return ColorManager.primaryBlue
        case title.contains("Temel Kurallar"):
            return ColorManager.primaryPurple
        case title.contains("Sayı Girişi"):
            return ColorManager.primaryOrange
        case title.contains("Notlar"):
            return Color.blue
        case title.contains("İpuçları"):
            return Color.yellow
        case title.contains("Hazırsınız"):
            return ColorManager.primaryGreen
        default:
            return Color.gray
        }
    }
    
    // Örnek strateji görünümleri
    func tutorialExampleView(forStep step: Int) -> some View {
        Group {
            if step == 5 { // Tek Olasılık Stratejisi
                singlePossibilityExample
            } else if step == 6 { // Tek Konum Stratejisi
                singleLocationExample
            } else {
                Text("Örnek Gösterilemiyor")
            }
        }
    }
    
    // Tek olasılık stratejisi örneği
    var singlePossibilityExample: some View {
        VStack(spacing: 12) {
            Text("Örnek: Bu hücreye sadece 4 girebilir")
                .font(.caption)
                .bold()
                .padding(.bottom, 5)
            
            // Mini 3x3 sudoku örneği
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
            
            Text("Satır, sütun ve 3x3 bölgesindeki diğer sayılar nedeniyle, bu hücreye sadece 4 yerleştirilebilir.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
        }
    }
    
    // Tek konum stratejisi örneği
    var singleLocationExample: some View {
        VStack(spacing: 12) {
            Text("Örnek: 5 sayısı sadece bu hücreye yerleştirilebilir")
                .font(.caption)
                .bold()
                .padding(.bottom, 5)
            
            // Mini 3x3 sudoku örneği
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
                                    // Vurgulanmış hücrede 5 göster ve animasyon ekle
                                    Text("5")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                        .scaleEffect(highlightScale ? 1.2 : 1.0)
                                        .onAppear {
                                            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                                highlightScale.toggle()
                                            }
                                        }
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
            
            Text("Bölgede sadece bu hücreye 5 yerleştirilebilir çünkü diğer hücrelerde 5 için yer yok.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
        }
    }
}

// Rehber adımı modeli
struct TutorialStep {
    let title: String
    let description: String
    let image: String
    let tip: String
}

// Preview
struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView()
    }
}

// Not: scaleInOut uzantısı ViewTransitionExtension.swift dosyasında tanımlandığı için burada kaldırıldı
