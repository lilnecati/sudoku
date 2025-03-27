//  TutorialOverlayView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 23.08.2024.
//

import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var tutorialManager: TutorialManager
    var onComplete: () -> Void
    
    // Animasyon değişkenleri
    @State private var showHighlight = false
    @State private var pulseOpacity = 0.0
    @State private var cardScale = 0.95
    @State private var contentOpacity = 0.0
    @State private var showSpotlight = false
    @StateObject private var powerManager = PowerSavingManager.shared
    
    var body: some View {
        let currentStep = tutorialManager.currentStep
        
        ZStack {
            // Karartılmış arka plan
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .opacity(showSpotlight ? 0.85 : 0.7)
                .animation(.easeInOut(duration: 0.3), value: showSpotlight)
            
            // Rehber içeriği
            VStack {
                Spacer()
                
                // Ana içerik kartı
                VStack {
                // Başlık
                Text(currentStep.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)
                    .id("title_\(currentStep.rawValue)") // Animasyon için benzersiz ID
                
                // İlerleme göstergesi
                ProgressView(value: tutorialManager.progressPercentage, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.teal))
                    .padding(.horizontal)
                    .animation(.easeInOut, value: tutorialManager.progressPercentage)
                
                // Açıklama
                Text(currentStep.description)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: 350)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.teal.opacity(0.2))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    )
                    .id("desc_\(currentStep.rawValue)") // Animasyon için benzersiz ID
                
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6).opacity(0.9))
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .scaleEffect(cardScale)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Butonlar
                HStack {
                    // Sadece ikinci adımdan sonra geri butonu göster
                    if currentStep != .welcome {
                        Button {
                            withAnimation {
                                tutorialManager.previousStep()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Geri")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.5))
                                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                            )
                            .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Son adımda "Tamam" butonu göster
                    Button {
                        withAnimation {
                            if currentStep == .completed {
                                onComplete()
                            } else {
                                tutorialManager.nextStep()
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentStep == .completed ? "Tamam" : "İleri")
                            if currentStep != .completed {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                        .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.5))
                )
                .scaleEffect(cardScale)
                .opacity(contentOpacity)
            }
            .padding()
                    .shadow(radius: 10)
            
            .frame(maxWidth: 400)
            .padding()
            
            // Vurgu efekti (özel hedef varsa)
            if !currentStep.highlightTarget.isEmpty {
                highlightView
            }
        }
        .onAppear {
            // Vurgu animasyonunu başlat
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showHighlight = true
                pulseOpacity = 0.6
            }
        }
    }
    
    // Öğretici adımına göre vurgu görünümü
    private var highlightView: some View {
        GeometryReader { geometry in
            let currentStep = tutorialManager.currentStep
            let target = currentStep.highlightTarget
            let targetFrame = getTargetFrame(for: target, in: geometry.size)
            
            // Vurgu çemberi
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .scaleEffect(showHighlight ? 1.1 : 0.9)
                .opacity(pulseOpacity)
                .frame(width: 120, height: 120)
                .position(
                    x: targetFrame.midX,
                    y: targetFrame.midY
                )
        }
    }
    
    // İlgili hedefin konumunu belirle
    private func getTargetFrame(for target: String, in size: CGSize) -> CGRect {
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        switch target {
        case "board":
            return CGRect(
                x: centerX,
                y: centerY - 100, 
                width: 0, 
                height: 0
            )
        case "numberPad":
            return CGRect(
                x: centerX,
                y: centerY + 200, 
                width: 0, 
                height: 0
            )
        case "notesButton":
            return CGRect(
                x: centerX + 70,
                y: centerY - 200, 
                width: 0, 
                height: 0
            )
        case "hintButton":
            return CGRect(
                x: centerX - 70,
                y: centerY - 200, 
                width: 0, 
                height: 0
            )
        default:
            return CGRect(x: centerX, y: centerY, width: 0, height: 0)
        }
    }
}

// Yardımcı buton görünümü
struct TutorialButton: View {
    var action: () -> Void
    @State private var isHovering = false
    @State private var wasPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                Text("Rehber")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.purple)
            )
        }
    }
}
