//  SettingsView.swift
//  Sudoku
//
//  Created by Necati Yıldırım on 28.11.2024.
//

import SwiftUI
import CoreData
import Combine

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
                .font(.system(size: 30, weight: .bold))
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
                    .font(.system(size: 16, weight: .medium))
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
                    .font(.system(size: 16, weight: .medium))
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
        
        // PowerSavingManager'ı sıfırla
        powerManager.powerSavingMode = false
        powerManager.autoPowerSaving = true
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
                            .font(.headline)
                        Text("Navigasyon sorunu giderilene kadar")
                            .font(.subheadline)
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
            // Arka plan - Anasayfadaki gradient stili uygulandı
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color(.systemGray6) : .white,
                    colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 25) {
                    // Modern başlık
                    HStack {
                        Text("Ayarlar")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()

                        // Pil durumu göstergesi
                        HStack(spacing: 8) {
                            Image(systemName: getBatteryIcon())
                                .foregroundColor(getBatteryColor())

                            Text("\(Int(PowerSavingManager.shared.batteryLevel * 100))%")
                                .font(.system(size: 14, weight: .medium))
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

            // Mevcut kullanıcıyı al
            currentUser = PersistenceController.shared.getCurrentUser()

            // Şarj durumu değişikliğini kontrol et
            let isCharging = PowerSavingManager.shared.isCharging
            if previousChargingState != isCharging {
                print("Cihaz şarj oluyor mu? \(isCharging)")
                previousChargingState = isCharging
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.leading, 8)
    }
    
    private func gameSettingsView() -> some View {
        VStack(spacing: 20) {
            // Ses Efektleri - modern toggle ile
            ToggleSettingRow(
                title: "Ses Efektleri",
                description: "Oyun içi ses efektlerini aç/kapa",
                isOn: $enableSoundEffects,
                iconName: "speaker.wave.2.fill",
                color: .blue
            )
            
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("%\(Int(soundVolume * 100))")
                                .font(.system(size: 14, weight: .medium))
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
                                    .font(.system(size: 14, weight: .medium))
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
            
            // Titreşim geri bildirimi - modern toggle ile
            ToggleSettingRow(
                title: "Titreşim Geri Bildirimi",
                description: "Oyun içi titreşim efektlerini aç/kapa",
                isOn: $enableHapticFeedback,
                iconName: "iphone.radiowaves.left.and.right",
                color: .orange
            )
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Cihazın görünüm ayarını kullan (açık/koyu)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu
                ZStack {
                    Capsule()
                        .fill(themeManager.useSystemAppearance ? Color.indigo : Color.gray.opacity(0.3))
                        .frame(width: 51, height: 31)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: themeManager.useSystemAppearance ? 10 : -10)
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: themeManager.useSystemAppearance)
                .onTapGesture {
                    SoundManager.shared.playNavigationSound()
                    themeManager.useSystemAppearance.toggle()
                }
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Karanlık tema aktif eder")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Toggle butonu
                    ZStack {
                        Capsule()
                            .fill(themeManager.darkMode ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 51, height: 31)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 27, height: 27)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: themeManager.darkMode ? 10 : -10)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: themeManager.darkMode)
                    .onTapGesture {
                        SoundManager.shared.playNavigationSound()
                        themeManager.darkMode.toggle()
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Seçim butonları
                    HStack(spacing: 12) {
                        TextSizeButton(
                            title: "Küçük",
                            isSelected: textSizeString == TextSizePreference.small.rawValue,
                            action: {
                                SoundManager.shared.playNavigationSound()
                                textSizeString = TextSizePreference.small.rawValue
                            }
                        )
                        
                        TextSizeButton(
                            title: "Orta", 
                            isSelected: textSizeString == TextSizePreference.medium.rawValue,
                            action: {
                                SoundManager.shared.playNavigationSound()
                                textSizeString = TextSizePreference.medium.rawValue
                            }
                        )
                        
                        TextSizeButton(
                            title: "Büyük", 
                            isSelected: textSizeString == TextSizePreference.large.rawValue,
                            action: {
                                SoundManager.shared.playNavigationSound()
                                textSizeString = TextSizePreference.large.rawValue
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
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
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
                    HStack {
                        Text("Pil Durumu")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("(%\(Int(powerManager.batteryLevel * 100)))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(getBatteryColor())
                    }
                    
                    // Pil durum mesajı
                    if powerManager.batteryLevel <= 0.2 {
                        Text("Düşük Pil")
                            .font(.system(size: 14, weight: .medium))
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
                
                // Düşük pilde güç tasarrufu önerisi
                if powerManager.batteryLevel <= 0.2 && !powerSavingMode {
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        powerSavingMode = true
                        powerManager.powerSavingMode = true
                    }) {
                        HStack {
                            Image(systemName: "bolt.shield")
                                .font(.system(size: 12))
                            
                            Text("Güç Tasarrufu")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.15))
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
            
            // Güç tasarrufu modu - modern toggle ile
            ToggleSettingRow(
                title: "Güç Tasarrufu Modu",
                description: "Animasyonları ve görsel efektleri azaltır",
                isOn: $powerSavingMode,
                iconName: "bolt.shield.fill",
                color: .green
            )
            
            // Otomatik güç tasarrufu - modern toggle ile
            ToggleSettingRow(
                title: "Otomatik Güç Tasarrufu",
                description: "Pil seviyesi düşükken otomatik olarak etkinleşir",
                isOn: $autoPowerSaving,
                iconName: "bolt.circle.fill",
                color: .orange
            )
            
            // Açıklama kartı
            HStack(alignment: .top, spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Güç Tasarrufu Hakkında")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Güç tasarrufu modu, pil ömrünü uzatmak için animasyonları azaltır ve bazı görsel efektleri kapatır. Otomatik mod, pil %20'nin altına düştüğünde kendiliğinden devreye girer.")
                        .font(.system(size: 14))
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
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // İsim ve Sürüm
                Text("Sudoku")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Sürüm 1.0")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
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
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Necati Yıldırım")
                            .font(.system(size: 16, weight: .medium))
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
                        .font(.system(size: 16, weight: .medium))
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
            Text("© 2025 Necati Yıldırım")
                .font(.system(size: 14, weight: .regular))
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
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
}

struct SettingRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(title)
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
    
    var body: some View {
        Button(action: {
            SoundManager.shared.playNavigationSound()
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 13))
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