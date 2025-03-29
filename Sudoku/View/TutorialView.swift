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
            // Arka plan
            Color.darkModeBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Başlık
                Text("Sudoku Rehberi")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                    .padding(.top)
                
                // İlerleme göstergesi
                ProgressView(value: Double(currentStep), total: Double(tutorialSteps.count - 1))
                    .padding(.horizontal)
                    .padding(.top, 5)
                
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
                HStack {
                    // Geri butonu
                    Button(action: {
                        SoundManager.shared.executeSound(.tap)
                        if currentStep > 0 {
                            withAnimation {
                                currentStep -= 1
                            }
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: currentStep == 0 ? "xmark" : "chevron.left")
                            Text(currentStep == 0 ? "Kapat" : "Geri")
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
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
                            Text(currentStep == tutorialSteps.count - 1 ? "Bitir" : "İleri")
                            Image(systemName: currentStep == tutorialSteps.count - 1 ? "checkmark" : "chevron.right")
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
    
    // Rehber adımı görünümü
    private func tutorialStepView(step: TutorialStep, stepNumber: Int) -> some View {
        VStack(spacing: 20) {
            // Adım başlığı
            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: true))
                .multilineTextAlignment(.center)
                .padding(.top)
                .transition(.scale.combined(with: .opacity))
            
            // Adım numarası
            Text("Adım \(stepNumber)/\(tutorialSteps.count)")
                .font(.subheadline)
                .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: false))
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
                .transition(.slide)
            
            // Görsel ve örnek icerik
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground(for: colorScheme))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
                
                if step.title.contains("Tek Olasılık") || step.title.contains("Tek Konum") {
                    // Strateji örnekleri için mini Sudoku tablosu göster
                    tutorialExampleView(forStep: stepNumber)
                        .padding()
                } else {
                    VStack {
                        // Üstte ikon
                        Image(systemName: getIconForStep(step: step))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color.accentColor)
                            .padding()
                            .transition(.scale)
                        
                        // Arkaplan öğeleri (değişen animasyonlar)
                        if step.title.contains("Hoş Geldiniz") {
                            // Rasgele sayılar animasyonu
                            sudokuWelcomeAnimation
                        } else if step.title.contains("Sayı Girişi") {
                            // Sayı giriş animasyonu
                            sudokuInputAnimation
                        } else if step.title.contains("Notlar") {
                            // Not alma animasyonu
                            sudokuNotesAnimation
                        }
                    }
                }
            }
            .frame(height: 230)
            .padding(.horizontal)
            
            // Açıklama
            Text(step.description)
                .font(.body)
                .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: false))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // İpucu
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("İpucu: \(step.tip)")
                    .font(.callout)
                    .foregroundColor(Color.textColor(for: colorScheme, isHighlighted: false))
            }
            .padding()
            .background(Color.buttonBackground(for: colorScheme))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .scaleInOut(isShowing: true)
    }
}

// Rehber adımı modeli
struct TutorialStep {
    let title: String
    let description: String
    let image: String
    let tip: String
}

// MARK: - Animasyon ve Yardımcı Görünümler
extension TutorialView {
    // Adıma uygun ikon seçimi
    func getIconForStep(step: TutorialStep) -> String {
        if step.title.contains("Hoş Geldiniz") {
            return "square.grid.3x3.fill"
        } else if step.title.contains("Temel Kurallar") {
            return "checkmark.seal.fill"
        } else if step.title.contains("Sayı Girişi") {
            return "hand.tap.fill"
        } else if step.title.contains("Notlar") {
            return "pencil.and.outline"
        } else if step.title.contains("Strateji") || step.title.contains("Olasılık") {
            return "brain.fill"
        } else if step.title.contains("İpuçları") {
            return "questionmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
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
    
    // Hoş geldiniz animasyonu - rastgele sayılar
    var sudokuWelcomeAnimation: some View {
        ZStack {
            ForEach(0..<10) { index in
                Text("\(Int.random(in: 1...9))")
                    .font(.title)
                    .foregroundColor(Color.accentColor.opacity(Double.random(in: 0.2...0.7)))
                    .position(
                        x: CGFloat.random(in: 40...280),
                        y: CGFloat.random(in: 20...100)
                    )
                    .opacity(animationProgress)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            animationProgress = Double.random(in: 0.3...1.0)
                        }
                    }
            }
        }
    }
    
    // Sayı girişi animasyonu
    var sudokuInputAnimation: some View {
        VStack {
            ZStack {
                // 3x3 mini ızgara
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .background(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                // Animasyonlu sayı girişi
                Text("\(inputAnimationValue)")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .scaleEffect(animateInputValue ? 1.2 : 0.8)
                    .opacity(animateInputValue ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5), value: animateInputValue)
                    .onAppear {
                        // Sayı değiştirme animasyonu
                        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                            animateInputValue = false
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                inputAnimationValue = [1, 3, 5, 7, 9].randomElement() ?? 5
                                withAnimation {
                                    animateInputValue = true
                                }
                            }
                        }
                    }
            }
            
            // Klavye gösterimi
            HStack(spacing: 5) {
                ForEach(1...3, id: \.self) { num in
                    Text("\(num)")
                        .frame(width: 25, height: 25)
                        .background(num == inputAnimationValue ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.top, 20)
        }
    }
    
    // Not alma animasyonu
    var sudokuNotesAnimation: some View {
        VStack {
            ZStack {
                // 3x3 mini ızgara
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .background(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                // Not içeriği - mini sayılar
                VStack(spacing: 2) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<3) { col in
                                let num = row * 3 + col + 1
                                if notesSet.contains(num) {
                                    Text("\(num)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .frame(width: 12, height: 12)
                                        .opacity(animateNote && lastAddedNote == num ? 0.3 : 1.0)
                                        .scaleEffect(animateNote && lastAddedNote == num ? 1.5 : 1.0)
                                } else {
                                    Spacer()
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                }
            }
            
            // Açıklama
            Text("Uzun basarak not ekleyin")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 10)
        }
        .onAppear {
            // Not ekleme animasyonu
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                let availableNotes = Array(1...9).filter { !notesSet.contains($0) }
                if let noteToAdd = availableNotes.randomElement() {
                    lastAddedNote = noteToAdd
                    withAnimation(.spring()) {
                        animateNote = true
                        notesSet.insert(noteToAdd)
                    }
                    
                    // Animasyonu sıfırla
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            animateNote = false
                        }
                    }
                } else {
                    // Tüm notlar eklendiyse temizle ve yeniden başla
                    notesSet.removeAll()
                }
            }
        }
    }
}

// Preview
struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        TutorialView()
    }
}

// Not: scaleInOut uzantısı ViewTransitionExtension.swift dosyasında tanımlandığı için burada kaldırıldı
