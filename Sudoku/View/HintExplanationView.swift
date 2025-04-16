//  HintExlanationVion.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 15.10.2024.
//

import SwiftUI

struct HintExplanationView: View {
    @ObservedObject var viewModel: SudokuViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // Animasyon durumları
    @State private var isShowing = false
    @State private var offsetY: CGFloat = 120 // Panel alt kısımdan yükselecek
    @StateObject private var powerManager = PowerSavingManager.shared
    
    // Önizleme için test verisi
    private static let testData: SudokuViewModel.HintData = {
        let data = SudokuViewModel.HintData(
            row: 3, 
            column: 4, 
            value: 5, 
            reason: "Bu hücreye 5 değeri konabilir."
        )
        
        // Test verisi için vurgulama ekleyelim
        data.highlightCell(row: data.row, column: data.column, type: SudokuViewModel.CellInteractionType.target)
        return data
    }()
    
    var body: some View {
        // Veri kaynağı
        let hintData = viewModel.hintExplanationData ?? Self.testData
        
        ZStack(alignment: .bottom) {
            // Saydam arka plan, sadece dokunma işlemlerini yakalamak için
            Color.clear
                .contentShape(Rectangle())
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissHint()
                }
            
            // Alt panel - görsellerdeki gibi sadece altta, tablo içeriğini kapatmadan
            VStack(spacing: 0) {
                // Başlık 
                Group {
                    let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
                    
                    if languageCode == "en" {
                        // İngilizce başlık
                        switch hintData.technique {
                        case .nakedSingle:
                            Text("Single Possibility Detection")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 15)
                                .padding(.bottom, 10)
                        case .hiddenSingle:
                            Text("Single Position Detection")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 15)
                                .padding(.bottom, 10)
                        case .general:
                            Text("Last Remaining Cell")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 15)
                                .padding(.bottom, 10)
                        default:
                            Text("Hint")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 15)
                                .padding(.bottom, 10)
                        }
                    } else {
                        // Türkçe başlık (varsayılan)
                        Text(hintData.stepTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.top, 15)
                            .padding(.bottom, 10)
                    }
                }
                
                // Açıklama - mavi veya yeşil renkli metinler (görsellerdeki gibi)
                Group {
                    let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
                    
                    if languageCode == "en" {
                        // İngilizce görünüm için açıklamaları manuel olarak çevirelim
                        if hintData.technique == .nakedSingle {
                            Text("Only the value \(hintData.value) can be placed in this cell because all other numbers have been eliminated.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 15)
                                .foregroundColor(getStepColor(for: viewModel.currentHintStep, hint: hintData))
                        } else if hintData.technique == .hiddenSingle {
                            Text("The number \(hintData.value) can only be placed in this cell in this region.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 15)
                                .foregroundColor(getStepColor(for: viewModel.currentHintStep, hint: hintData))
                        } else {
                            // Diğer ipucu teknikleri için
                            Text("According to Sudoku rules, the value \(hintData.value) can be placed in this cell.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 15)
                                .foregroundColor(getStepColor(for: viewModel.currentHintStep, hint: hintData))
                        }
                    } else {
                        // Türkçe görünüm (varsayılan)
                        Text(hintData.stepDescription)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 15)
                            .foregroundColor(getStepColor(for: viewModel.currentHintStep, hint: hintData))
                    }
                }
                
                // Adım göstergeleri - görsellerdeki gibi alt kısımda
                HStack(spacing: 20) {
                    // Geri butonu
                    Button(action: {
                        if viewModel.currentHintStep > 0 {
                            viewModel.currentHintStep -= 1
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(viewModel.currentHintStep > 0 ? .blue : .gray.opacity(0.5))
                    }
                    .disabled(viewModel.currentHintStep == 0)
                    
                    // Sayfa indikatörleri (noktalar) - görsellerdeki gibi
                    HStack(spacing: 6) {
                        ForEach(0..<hintData.totalSteps, id: \.self) { index in
                            Circle()
                                .fill(index == viewModel.currentHintStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.currentHintStep)
                        }
                    }
                    
                    // İleri/Bitti butonu
                    Button(action: {
                        if viewModel.currentHintStep < hintData.totalSteps - 1 {
                            viewModel.currentHintStep += 1
                        } else {
                            dismissHint()
                        }
                    }) {
                        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
                        
                        if languageCode == "en" {
                            // İngilizce buton metni
                            Text(viewModel.currentHintStep < hintData.totalSteps - 1 ? "Next" : "Finished")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                        } else {
                            // Türkçe buton metni
                            Text(viewModel.currentHintStep < hintData.totalSteps - 1 ? "İleri" : "Bitti")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.bottom, 15)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .cornerRadius(16)
            .frame(maxWidth: .infinity, minHeight: 200) // Yüksekliğini daha fazla artırdım, yukarıya doğru uzaması için
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            .offset(y: isShowing ? 0 : offsetY) // Alt kısımdan yükselme efekti
            .animation(.spring(response: powerManager.isPowerSavingEnabled ? 0.3 : 0.5, 
                             dampingFraction: 0.8), value: isShowing)
            .animation(.spring(response: powerManager.isPowerSavingEnabled ? 0.3 : 0.5, 
                             dampingFraction: 0.8), value: offsetY)
            .onAppear {
                // Güç tasarrufu moduna göre animasyon ayarları
                withAnimation {
                    isShowing = true
                    offsetY = 0
                }
            }
        }
    }
    
    // Adıma ve ipucu tekniğine göre renk belirleme - görsellerdeki gibi
    private func getStepColor(for step: Int, hint: SudokuViewModel.HintData) -> Color {
        // Görsellerde mavi ve yeşil vurgulamalar vardı
        if hint.technique == .nakedSingle || hint.technique == .hiddenSingle {
            return .green // Yeşil renkli metinler
        } else if hint.technique == .nakedPair || hint.technique == .hiddenPair {
            return .blue // Mavi renkli metinler
        }
        return .blue // Varsayılan renk
    }
    
    // Hint ekranını kapatma fonksiyonu
    private func dismissHint() {
        // Güç tasarrufu moduna göre animasyon süresi ayarlanır
        let animationDuration = powerManager.isPowerSavingEnabled ? 0.2 : 0.3
        
        // Aşağı doğru kayarak kapanma animasyonu
        withAnimation(.easeInOut(duration: animationDuration)) {
            isShowing = false
            offsetY = 120 // Ekranın altına doğru kayma
        }
        
        // Animasyon tamamlandıktan sonra viewModel'deki değerleri sıfırla
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.05) {
            viewModel.hintExplanationData = nil
            viewModel.currentHintStep = 0
            viewModel.showHintExplanation = false
        }
    }

}

// Önizleme
struct HintExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SudokuViewModel()
        let hintData = SudokuViewModel.HintData(
            row: 2, 
            column: 3,
            value: 5,
            reason: "Bu hücreye 5 değeri konabilir çünkü aynı satır, sütun ve 3x3 bloktaki diğer sayılarla çakışmaz.",
            technique: SudokuViewModel.HintTechnique.general
        )
        hintData.addStep(title: "Adım 1", description: "İlk adım açıklaması")
        hintData.addStep(title: "Adım 2", description: "İkinci adım açıklaması")
        viewModel.hintExplanationData = hintData
        viewModel.showHintExplanation = true
        
        return Group {
            HintExplanationView(viewModel: viewModel)
                .previewLayout(.fixed(width: 350, height: 400))
            
            HintExplanationView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .previewLayout(.fixed(width: 350, height: 400))
        }
    }
}
