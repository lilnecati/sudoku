//  SettingsView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 28.11.2024.
//

import SwiftUI
import CoreData
import Combine

// ScaledFont modifier - metinlerin ölçeklenmesi için
struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    
    private var textSizePreference: TextSizePreference {
        return TextSizePreference(rawValue: textSizeString) ?? .medium
    }
    
    func body(content: Content) -> some View {
        let scaledSize = size * textSizePreference.scaleFactor
        return content.font(.system(size: scaledSize, weight: weight))
    }
}

// View uzantısı olarak kullanım kolaylaştırma
extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        return self.modifier(ScaledFont(size: size, weight: weight))
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    // ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // App Storage
    @AppStorage("defaultDifficulty") private var defaultDifficulty: String = SudokuBoard.Difficulty.easy.rawValue
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("enableNumberInputHaptic") private var enableNumberInputHaptic: Bool = true
    @AppStorage("enableCellTapHaptic") private var enableCellTapHaptic: Bool = true
    @AppStorage("enableSoundEffects") private var enableSoundEffects: Bool = true
    @AppStorage("soundVolume") private var soundVolume: Double = 0.7
    @AppStorage("textSizePreference") private var textSizeString: String = TextSizePreference.medium.rawValue
    @AppStorage("prefersDarkMode") private var prefersDarkMode: Bool = false
    @AppStorage("powerSavingMode") private var powerSavingMode: Bool = false
    @AppStorage("autoPowerSaving") private var autoPowerSaving: Bool = true
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    
    // PowerSavingManager'a erişim
    @StateObject private var powerManager = PowerSavingManager.shared
    
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var name = ""
    @State private var showLoginView = false
    @State private var showRegisterView = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isRefreshing = false
    
    // Mevcut kullanıcı bilgisi
    @State private var currentUser: NSManagedObject? = nil

    @State private var previousChargingState: Bool?
    
    // Pil simgesini al
    private func getBatteryIcon() -> String {
        let level = PowerSavingManager.shared.batteryLevel
        let isCharging = PowerSavingManager.shared.isCharging
        
        let batteryLevel: String
        if level <= 0.1 {
            batteryLevel = "battery.0"
        } else if level <= 0.25 {
            batteryLevel = "battery.25"
        } else if level <= 0.5 {
            batteryLevel = "battery.50"
        } else if level <= 0.75 {
            batteryLevel = "battery.75"
        } else {
            batteryLevel = "battery.100"
        }
        
        return isCharging ? batteryLevel + ".charge" : batteryLevel
    }
    
    // Pil rengini al
    private func getBatteryColor() -> Color {
        let level = PowerSavingManager.shared.batteryLevel
        if level <= 0.1 {
            return .red
        } else if level <= 0.25 {
            return .orange
        } else {
            return .green
        }
    }
    
    // Pil arka plan rengini al
    private func getBatteryBackgroundColor() -> Color {
        let level = PowerSavingManager.shared.batteryLevel
        let isCharging = PowerSavingManager.shared.isCharging
        
        if isCharging {
            return Color.blue
        } else if level <= 0.1 {
            return Color.red
        } else if level <= 0.25 {
            return Color.orange
        } else {
            return Color.green
        }
    }
    
    private var textSizePreference: TextSizePreference {
        get {
            return TextSizePreference(rawValue: textSizeString) ?? .medium
        }
        set {
            textSizeString = newValue.rawValue
        }
    }
    
    // Alt bileşenler - derleyici yükünü azaltmak için
    private func profileCircle(initial: String) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                )
                .frame(width: 70, height: 70)
            
            Text(initial)
                .scaledFont(size: 30, weight: .bold)
                .foregroundColor(.white)
        }
    }
    
    private func logoutButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                Text("Çıkış Yap")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color.red
                    .cornerRadius(12)
                    .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    private func loginButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 16))
                Text("Giriş Yap")
                    .scaledFont(size: 16, weight: .medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.blue
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    private func registerButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 16))
                Text("Kayıt Ol")
                    .scaledFont(size: 16, weight: .medium)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    private func websiteLink(url: String, displayText: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: "globe")
                Text(displayText)
                    .scaledFont(size: 14)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .foregroundColor(.primary)
        }
    }
    
    // Tüm ayarları sıfırla
    private func resetAllSettings() {
        enableHapticFeedback = true
        enableNumberInputHaptic = true
        enableCellTapHaptic = true
        enableSoundEffects = true
        textSizeString = TextSizePreference.medium.rawValue
        defaultDifficulty = SudokuBoard.Difficulty.easy.rawValue
        powerSavingMode = false
        autoPowerSaving = true
        highPerformanceMode = false
        
        // PowerSavingManager'ı sıfırla
        powerManager.powerSavingMode = false
        powerManager.autoPowerSaving = true
        powerManager.setPowerSavingLevel(.off)
    }
    
    private func userProfileSection() -> some View {
        // Giriş yapma ve profil işlemleri geçici olarak devre dışı bırakıldı
        return AnyView(
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text("Profil Devre Dışı")
                            .scaledFont(size: 17, weight: .semibold)
                        Text("Navigasyon sorunu giderilene kadar")
                            .scaledFont(size: 14)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
        )
    }
    
    var body: some View {
        ZStack {
            // Izgara arka planı
            GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 25) {
                    // Modern başlık
                    HStack {
                        Text("Ayarlar")
                            .scaledFont(size: 32, weight: .bold)
                            .foregroundColor(.primary)

                        Spacer()

                        // Pil durumu göstergesi
                        HStack(spacing: 8) {
                            Image(systemName: getBatteryIcon())
                                .foregroundColor(getBatteryColor())

                            Text("\(Int(PowerSavingManager.shared.batteryLevel * 100))%")
                                .scaledFont(size: 14, weight: .medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color(hex: "252525") : Color(hex: "F0F0F5"))
                        )
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)

                    // Kullanıcı profili
                    userProfileSection()
                        .padding(.horizontal)

                    // Oyun ayarları - modern tasarım
                    settingsSection(title: "Oyun Ayarları", systemImage: "gamecontroller.fill") {
                        gameSettingsView()
                    }

                    // Görünüm ayarları - modern tasarım
                    settingsSection(title: "Görünüm Ayarları", systemImage: "paintpalette.fill") {
                        appearanceSettingsView()
                    }

                    // Güç tasarrufu ayarları - modern tasarım
                    settingsSection(title: "Güç Tasarrufu", systemImage: "bolt.fill") {
                        powerSavingSettingsView()
                    }

                    // Hakkında bölümü - modern tasarım
                    settingsSection(title: "Hakkında", systemImage: "info.circle.fill") {
                        aboutSettingsView()
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Pil durumunu güncelle
            UIDevice.current.isBatteryMonitoringEnabled = true
            powerSavingMode = powerManager.powerSavingMode
            autoPowerSaving = powerManager.autoPowerSaving
            highPerformanceMode = powerManager.highPerformanceMode

            // Mevcut kullanıcıyı al
            currentUser = PersistenceController.shared.getCurrentUser()

            // Şarj durumu değişikliğini kontrol et
            let isCharging = PowerSavingManager.shared.isCharging
            if previousChargingState != isCharging {
                print("Cihaz şarj oluyor mu? \(isCharging)")
                previousChargingState = isCharging
            }
            
            // Metin boyutu değişikliği bildirimini dinle
            NotificationCenter.default.addObserver(forName: Notification.Name("ForceUIUpdate"), object: nil, queue: .main) { _ in
                // View'i zorla yeniden çizdirmek için aşağıdaki kod yeterli
                print("📱 Metin boyutu güncellemesi algılandı: \(textSizePreference.rawValue)")
            }
        }
        .sheet(isPresented: $showLoginView) {
            LoginView(isPresented: $showLoginView, currentUser: $currentUser)
        }
        .sheet(isPresented: $showRegisterView) {
            RegisterView(isPresented: $showRegisterView, currentUser: $currentUser)
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Hata"), message: Text(errorMessage), dismissButton: .default(Text("Tamam")))
        }
    }
    
    private func settingsSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            // Başlık
            sectionHeader(title: title, systemImage: systemImage)
            
            content()
                .padding()
                .background(
                    backgroundRectangle()
                )
        }
    }
    
    private func backgroundRectangle(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func settingRowBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color.white)
    }
    
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack {
            // Modern ikon tasarımı
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
    
    private func gameSettingsView() -> some View {
        VStack(spacing: 20) {
            // Ses Efektleri
            HStack(spacing: 15) {
                // Sol taraftaki simge
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ses Efektleri")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text("Oyun içi ses efektlerini aç/kapa")
                        .scaledFont(size: 13)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu
                Button(action: {
                    // Titreşim kontrolü
                    if enableHapticFeedback {
                        SoundManager.shared.playNavigationSound()
                    } else {
                        SoundManager.shared.playNavigationSoundOnly()
                    }
                    
                    enableSoundEffects.toggle()
                }) {
                    ZStack {
                        Capsule()
                            .fill(enableSoundEffects ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 55, height: 34)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: enableSoundEffects ? 10 : -10)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: enableSoundEffects)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // Ses seviyesi kaydırıcısı - eğer ses açıksa
            if enableSoundEffects {
                HStack(spacing: 15) {
                    // İkon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Başlık ve değer
                        HStack {
                            Text("Ses Seviyesi")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("%\(Int(soundVolume * 100))")
                                .scaledFont(size: 14, weight: .medium)
                                .foregroundColor(.blue)
                        }
                        
                        // Slider
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            
                            Slider(value: $soundVolume, in: 0...1, step: 0.05)
                                .accentColor(.blue)
                                .onAppear {
                                    SoundManager.shared.updateVolumeLevel(soundVolume)
                                }
                                .onChange(of: soundVolume) { oldValue, newValue in
                                    SoundManager.shared.updateVolumeLevelQuietly(newValue)
                                }
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                        }
                        
                        // Test butonu
                        Button(action: {
                            SoundManager.shared.executeSound(.test)
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 14))
                                
                                Text("Sesi Test Et")
                                    .scaledFont(size: 14, weight: .medium)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                .transition(.opacity)
            }
            
            // Titreşim geri bildirimi
            HStack(spacing: 15) {
                // Sol taraftaki simge
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Titreşim Geri Bildirimi")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text("Oyun içi titreşim efektlerini aç/kapa")
                        .scaledFont(size: 13)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu - titreşim durumu için özel
                Button(action: {
                    // Eğer titreşim kapalıysa ve açılıyorsa, yani false iken true oluyor
                    if enableHapticFeedback == false {
                        // Açılırken titreşim verelim - direkt SoundManager kullanarak
                        SoundManager.shared.playNavigationSound()
                    } else {
                        // Kapanırken titreşim vermeyelim
                        SoundManager.shared.playNavigationSoundOnly()
                    }
                    
                    enableHapticFeedback.toggle()
                }) {
                    ZStack {
                        Capsule()
                            .fill(enableHapticFeedback ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 55, height: 34)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: enableHapticFeedback ? 10 : -10)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: enableHapticFeedback)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
        }
    }
    
    private func appearanceSettingsView() -> some View {
        VStack(spacing: 20) {
            // Sistem görünümünü kullan
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.indigo)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sistem Görünümünü Kullan")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text("Cihazın görünüm ayarını kullan (açık/koyu)")
                        .scaledFont(size: 13)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu
                Button(action: {
                    // Titreşim kontrolü yapılarak ses çal
                    if enableHapticFeedback {
                        SoundManager.shared.playNavigationSound()
                    } else {
                        SoundManager.shared.playNavigationSoundOnly()
                    }
                    
                    themeManager.useSystemAppearance.toggle()
                }) {
                    ZStack {
                        Capsule()
                            .fill(themeManager.useSystemAppearance ? Color.indigo : Color.gray.opacity(0.3))
                            .frame(width: 55, height: 34)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: themeManager.useSystemAppearance ? 10 : -10)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: themeManager.useSystemAppearance)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // Karanlık mod
            if !themeManager.useSystemAppearance {
                HStack(spacing: 15) {
                    // İkon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    
                    // Başlık ve açıklama
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Karanlık Mod")
                            .scaledFont(size: 16, weight: .semibold)
                            .foregroundColor(.primary)
                        
                        Text("Karanlık tema aktif eder")
                            .scaledFont(size: 13)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Toggle butonu
                    Button(action: {
                        // Titreşim kontrolü yapılarak ses çal
                        if enableHapticFeedback {
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        themeManager.darkMode.toggle()
                    }) {
                        ZStack {
                            Capsule()
                                .fill(themeManager.darkMode ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 55, height: 34)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: themeManager.darkMode ? 10 : -10)
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: themeManager.darkMode)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
            }
            
            // Metin boyutu
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "textformat.size")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Başlık
                    Text("Metin Boyutu")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    // Seçim butonları
                    HStack(spacing: 12) {
                        TextSizeButton(
                            title: "Küçük",
                            isSelected: textSizeString == TextSizePreference.small.rawValue,
                            action: {
                                updateTextSizePreference(TextSizePreference.small)
                            }
                        )
                        
                        TextSizeButton(
                            title: "Orta", 
                            isSelected: textSizeString == TextSizePreference.medium.rawValue,
                            action: {
                                updateTextSizePreference(TextSizePreference.medium)
                            }
                        )
                        
                        TextSizeButton(
                            title: "Büyük", 
                            isSelected: textSizeString == TextSizePreference.large.rawValue,
                            action: {
                                updateTextSizePreference(TextSizePreference.large)
                            }
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
        }
    }
    
    struct TextSizeButton: View {
        var title: String
        var isSelected: Bool
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .scaledFont(size: 14, weight: isSelected ? .semibold : .regular)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.orange.opacity(0.2) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .foregroundColor(isSelected ? .orange : .primary)
            }
        }
    }
    
    private func powerSavingSettingsView() -> some View {
        VStack(spacing: 20) {
            // Pil durumu göstergesi - resme uygun dikdörtgen tasarım
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "battery.0")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                
                // Başlık ve durum
                VStack(alignment: .leading, spacing: 4) {
                    // Pil durumu ve yüzde - tek satırda kalacak şekilde
                    HStack(spacing: 4) {
                        Text("Pil Durumu")
                            .scaledFont(size: 16, weight: .bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("\(Int(powerManager.batteryLevel * 100))%")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(getBatteryColor())
                            .lineLimit(1)
                    }
                    .minimumScaleFactor(0.8) // Yazı sığmazsa küçültebilir
                    
                    // Pil durum mesajı
                    if powerManager.batteryLevel <= 0.2 {
                        Text("Düşük Pil")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(.orange)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.2))
                            )
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            // Güç Tasarrufu Ayarları
            Section {
                // Güç tasarrufu modu
                HStack {
                    Label {
                        Text("Güç Tasarrufu Modu")
                            .scaledFont(size: 16, weight: .medium)
                    } icon: {
                        Image(systemName: "battery.50")
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Toggle görünümü - sadece buna basınca toggle olacak
                    Button(action: {
                        // Titreşim kontrolü yapılarak ses çal
                        if enableHapticFeedback {
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Değeri tersine çevir
                        powerSavingMode.toggle()
                        
                        if powerSavingMode {
                            PowerSavingManager.shared.setPowerSavingLevel(.medium)
                            // Yüksek performans modunu kapat
                            if highPerformanceMode {
                                highPerformanceMode = false
                            }
                        } else {
                            PowerSavingManager.shared.setPowerSavingLevel(.off)
                        }
                    }) {
                        ZStack {
                            Capsule()
                                .fill(powerSavingMode ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 55, height: 34)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: powerSavingMode ? 10 : -10)
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: powerSavingMode)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Yüksek performans modu
                HStack {
                    Label {
                        Text("Yüksek Performans Modu")
                            .scaledFont(size: 16, weight: .medium)
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                    
                    // Toggle görünümü - sadece buna basınca toggle olacak
                    Button(action: {
                        // Titreşim kontrolü yapılarak ses çal
                        if enableHapticFeedback {
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Değeri tersine çevir
                        highPerformanceMode.toggle()
                        
                        PowerSavingManager.shared.highPerformanceMode = highPerformanceMode
                        // Yüksek performans modunu açarken güç tasarrufunu kapat
                        if highPerformanceMode && powerSavingMode {
                            powerSavingMode = false
                        }
                    }) {
                        ZStack {
                            Capsule()
                                .fill(highPerformanceMode ? Color.yellow : Color.gray.opacity(0.3))
                                .frame(width: 55, height: 34)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: highPerformanceMode ? 10 : -10)
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: highPerformanceMode)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Otomatik güç tasarrufu
                HStack {
                    Label {
                        Text("Otomatik Güç Tasarrufu")
                            .scaledFont(size: 16, weight: .medium)
                    } icon: {
                        Image(systemName: "battery.25")
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // Toggle görünümü - sadece buna basınca toggle olacak
                    Button(action: {
                        // Titreşim kontrolü yapılarak ses çal
                        if enableHapticFeedback {
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Değeri tersine çevir
                        autoPowerSaving.toggle()
                        
                        PowerSavingManager.shared.isAutoPowerSavingEnabled = autoPowerSaving
                    }) {
                        ZStack {
                            Capsule()
                                .fill(autoPowerSaving ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 55, height: 34)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: autoPowerSaving ? 10 : -10)
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: autoPowerSaving)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // Güç tasarrufu açıklaması
                if powerSavingMode || autoPowerSaving {
                    Text("Güç tasarrufu modu, bazı görsel efektleri ve animasyonları devre dışı bırakır veya basitleştirir.")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Yüksek performans açıklaması
                if highPerformanceMode {
                    Text("Yüksek performans modu daha akıcı animasyonlar ve görsel efektler sağlar ancak pil kullanımını artırır.")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            } header: {
                Text("Performans")
                    .scaledFont(size: 18, weight: .bold)
            } footer: {
                Text("Güç tasarrufu modu, cihazınızın pil ömrünü uzatır.")
                    .scaledFont(size: 12)
            }
        }
    }
    
    private func aboutSettingsView() -> some View {
        VStack(spacing: 20) {
            // Uygulama logosu ve sürüm bilgisi
            VStack(spacing: 15) {
                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Text("S")
                        .scaledFont(size: 40, weight: .bold)
                        .foregroundColor(.white)
                }
                
                // İsim ve Sürüm
                Text("Sudoku")
                    .scaledFont(size: 24, weight: .bold)
                    .foregroundColor(.primary)
                
                Text("Sürüm 1.0")
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(.secondary)
                
                // Yatay çizgi
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 10)
                
                // Geliştirici bilgisi
                HStack(spacing: 15) {
                    // İkon
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.teal)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Geliştrici")
                            .scaledFont(size: 14)
                            .foregroundColor(.secondary)
                        
                        Text("Necati Yıldırım")
                            .scaledFont(size: 16, weight: .medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
            
            // Bilgi kartları
            InfoCard(
                title: "Uygulama Hakkında",
                description: "Bu Sudoku uygulaması, klasik Sudoku oyununu modern bir arayüzle sunmak için tasarlanmıştır. Dört farklı zorluk seviyesi, not alma özellikleri, ve daha fazlasıyla dolu bir oyun deneyimi sunar.",
                iconName: "info.circle.fill",
                color: .blue
            )
            
            // Tüm ayarları sıfırla
            Button(action: {
                resetAllSettings()
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                    
                    Text("Tüm Ayarları Sıfırla")
                        .scaledFont(size: 16, weight: .medium)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
            }
            
            // Telif hakkı ve yapım yılı
            Text("© 2024 Necati Yıldırım")
                .scaledFont(size: 14, weight: .regular)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    struct InfoCard: View {
        var title: String
        var description: String
        var iconName: String
        var color: Color
        
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            HStack(alignment: .top, spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .scaledFont(size: 14)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
        }
    }
    
    // TextSize değişikliğini işleme fonksiyonu
    private func updateTextSizePreference(_ newValue: TextSizePreference) {
        // Değişikliği AppStorage'a kaydet
        let previousValue = textSizePreference
        // String değeri güncelle
        textSizeString = newValue.rawValue
        
        // Değişikliği bildir
        NotificationCenter.default.post(name: Notification.Name("TextSizeChanged"), object: nil)
        
        // Bildirim sesi çal
        SoundManager.shared.playNavigationSound()
        
        // Görünümün tümünü zorla yenile
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
        
        print("📱 Metin boyutu değiştirildi: \(previousValue.rawValue) -> \(newValue.rawValue)")
    }
}

struct SettingRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(title)
                .scaledFont(size: 16)
                .foregroundColor(.primary)
            
            Spacer()
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
        )
    }
}

struct ToggleSettingRow: View {
    var title: String
    var description: String
    @Binding var isOn: Bool
    var iconName: String
    var color: Color
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    
    var body: some View {
        Button(action: {
            // Titreşim kontrolü - özellikle titreşim açık/kapalı düğmesi için
            if title == "Titreşim Geri Bildirimi" {
                // Titreşim düğmesi için, bu tuşu yönetiyoruz
                // Titreşim vermeden sadece ses çal
                SoundManager.shared.playNavigationSoundOnly()
            } else if enableHapticFeedback {
                // Diğer tüm düğmeler için, titreşim ayarı açıksa titreşimli ses çal
                SoundManager.shared.playNavigationSound()
            } else {
                // Titreşim kapalıysa, sadece ses çal
                SoundManager.shared.playNavigationSoundOnly()
            }
            
            isOn.toggle()
        }) {
            HStack(spacing: 15) {
                // Sol taraftaki simge
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .scaledFont(size: 13)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu
                ZStack {
                    Capsule()
                        .fill(isOn ? color : Color.gray.opacity(0.3))
                        .frame(width: 51, height: 31)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 10 : -10)
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isOn)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}
