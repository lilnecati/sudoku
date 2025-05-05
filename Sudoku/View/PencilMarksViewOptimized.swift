import SwiftUI

struct PencilMarksViewOptimized: View {
    let pencilMarks: Set<Int>
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / 3
            let cellHeight = geometry.size.height / 3
            
            ZStack(alignment: .topLeading) {
                // Minimal arka plan - hafif yuvarlatılmış çerçeve
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.gray.opacity(0.35), lineWidth: 0.5)
                    )
                
                ForEach(Array(pencilMarks).sorted(), id: \.self) { mark in
                    // Hücre içinde doğru konumlandırmak için indeks hesapla
                    let index = mark - 1
                    let row = index / 3
                    let col = index % 3
                    
                    Text("\(mark)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.75))
                        .frame(width: cellWidth, height: cellHeight)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.04))
                                .frame(width: min(cellWidth, cellHeight) * 0.75)
                        )
                        .position(
                            x: cellWidth * CGFloat(col) + cellWidth / 2,
                            y: cellHeight * CGFloat(row) + cellHeight / 2
                        )
                }
            }
            .drawingGroup(opaque: false, colorMode: .linear)
        }
    }
} 