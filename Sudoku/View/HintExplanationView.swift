import SwiftUI

struct HintExplanationView: View {
    @ObservedObject var viewModel: SudokuViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // Animasyon durumları
    @State private var isShowing = false
    @State private var pulseValue = false
    @StateObject private var powerManager = PowerSavingManager.shared
    
    var body: some View {
        // Sabit test verisi
        let testData = SudokuViewModel.HintData(
            row: 3, 
            column: 4, 
            value: 7, 
            reason: "Bu hücreye 7 değeri konabilir çünkü aynı satır, sütun ve 3x3 bloktaki diğer sayılarla çakışmaz."
        )
        
        // Veri kaynağı
        let hintData = viewModel.hintExplanationData ?? testData
        
        ZStack {
            // Karartma
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissHint()
                }
            
            // Ana içerik
            VStack(spacing: 12) {
                Text("İpucu Açıklaması")
                    .font(.headline)
                    .foregroundColor(.teal)
                
                Divider()
                
                // Hücre ve değer bilgisi
                HStack(spacing: 16) {
                    ZStack {
                        // Arka plan şekli
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.teal.opacity(0.3), Color.teal.opacity(0.15)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.teal.opacity(0.5), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                        
                        // Rakam
                        Text("\(hintData.value)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.teal)
                            .scaleEffect(pulseValue ? 1.1 : 1.0)
                    }
                    
                    Spacer()
                    
                    // Konum bilgisi
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                            Text("Satır: \(hintData.row + 1)")
                                .font(.subheadline)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.to.line")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                            Text("Sütun: \(hintData.column + 1)")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                // Açıklama metni
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow.opacity(0.8))
                        
                        Text("Neden bu değer?")
                            .font(.headline)
                            .foregroundColor(.teal)
                    }
                    
                    Text(hintData.reason)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color.teal.opacity(0.07))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                
                Spacer()
                
                // Kapat butonu
                Button {
                    dismissHint()
                } label: {
                    Text("Anladım")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .scaleEffect(isShowing ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.showHintExplanation)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
            .padding()
            .frame(maxWidth: 400)
            .scaleEffect(isShowing ? 1.0 : 0.8)
            .opacity(isShowing ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isShowing = true
                }
                
                // Güç tasarrufu modunda animasyonları azaltalım
                if !powerManager.isPowerSavingEnabled {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        pulseValue.toggle()
                    }
                }
            }
        }
    }
    
    // Hint ekranını kapatma fonksiyonu
    private func dismissHint() {
        withAnimation(.easeOut(duration: powerManager.isPowerSavingEnabled ? 0.2 : 0.3)) {
            isShowing = false
            viewModel.showHintExplanation = false
        }
    }
    
    // Madde işareti için yardımcı fonksiyon
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

// Önizleme
struct HintExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SudokuViewModel()
        viewModel.hintExplanationData = SudokuViewModel.HintData(
            row: 2, 
            column: 3, 
            value: 5, 
            reason: "Bu değer 3. satırda ve 4. sütunda başka 5 bulunmadığı için uygundur."
        )
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
