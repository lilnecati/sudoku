//  PencilMarksView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI

struct PencilMarksView: View {
    let pencilMarks: Set<Int>
    let cellSize: CGFloat
    
    var body: some View {
        // Daha küçük font boyutu kullanalım, böylece kare içine sığacak
        let fontSize = cellSize * 0.18
        
        // Sabit bir frame içinde kalem notlarını göster
        GeometryReader { geometry in
            // Ana çerçeve - bütün alanı kaplar
            ZStack(alignment: .center) {
                // Boş bir arka plan ile sabit boyutu zorla
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                
                // Notları düzenli bir şekilde göster - 3x3 grid
                VStack(spacing: 0) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<3) { col in
                                let number = row * 3 + col + 1
                                
                                // Her küçük hücre kesin bir boyuta sahip
                                ZStack {
                                    // Boş placeholder - her zaman görünmez alanı koru
                                    Rectangle()
                                        .foregroundColor(.clear)
                                        .frame(width: cellSize / 3, height: cellSize / 3)
                                    
                                    // Sadece ilgili kalem notu varsa içeriği göster
                                    if pencilMarks.contains(number) {
                                        Text("\(number)")
                                            .font(.system(size: fontSize, weight: .light, design: .rounded))
                                            .foregroundColor(.primary)
                                            // Kesin konumlandırma için merkeze sabitle
                                            .frame(width: cellSize / 3, height: cellSize / 3, alignment: .center)
                                            // Boyut bozulmasını önlemek için clipping
                                            .clipped()
                                    }
                                }
                                // Her bir sayı hücresi için sabit boyut
                                .frame(width: cellSize / 3, height: cellSize / 3, alignment: .center)
                            }
                        }
                        // Her satırın boyutunu sabitle
                        .frame(height: cellSize / 3)
                    }
                }
                // Tüm grid için sabit boyut
                .frame(width: cellSize, height: cellSize, alignment: .center)
            }
            // Dış konteyner - GeometryReader boyutlarını kullanarak
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        // Oranları koruyarak kare form korunmalı
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    VStack {
        HStack {
            PencilMarksView(pencilMarks: [1, 3, 5, 7, 9], cellSize: 60)
                .background(Color.gray.opacity(0.1))
                .frame(width: 60, height: 60)
            
            PencilMarksView(pencilMarks: [2, 4, 6, 8], cellSize: 60)
                .background(Color.gray.opacity(0.1))
                .frame(width: 60, height: 60)
        }
        
        HStack {
            PencilMarksView(pencilMarks: [1, 2, 3], cellSize: 60)
                .background(Color.gray.opacity(0.1))
                .frame(width: 60, height: 60)
            
            PencilMarksView(pencilMarks: [7, 8, 9], cellSize: 60)
                .background(Color.gray.opacity(0.1))
                .frame(width: 60, height: 60)
        }
    }
    .padding()
} 
