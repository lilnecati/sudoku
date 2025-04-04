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
        let background = Color.darkModeBackground(for: colorScheme)
        let batteryIcon = getBatteryIcon()
        let batteryColor = getBatteryColor()
        let batteryLevel = Int(PowerSavingManager.shared.batteryLevel * 100)

        return ZStack {
            background
                .ignoresSafeArea()

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
                            Image(systemName: batteryIcon)
                                .foregroundColor(batteryColor)

                            Text("\(batteryLevel)%")
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
        VStack(spacing: 5) {
            // Varsayılan zorluk
            HStack {
                Text("Varsayılan Zorluk")
                Spacer()
                Menu {
                    Button("Kolay") { defaultDifficulty = SudokuBoard.Difficulty.easy.rawValue }
                    Button("Orta") { defaultDifficulty = SudokuBoard.Difficulty.medium.rawValue }
                    Button("Zor") { defaultDifficulty = SudokuBoard.Difficulty.hard.rawValue }
                    Button("Çok Zor") { defaultDifficulty = SudokuBoard.Difficulty.expert.rawValue }
                } label: {
                    Text(defaultDifficulty)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Titreşim geri bildirimi ana ayarı
            HStack {
                Text("Titreşim Geri Bildirimi")
                Spacer()
                Button(action: {
                    SoundManager.shared.playNavigationSound()
                    enableHapticFeedback.toggle()
                    // Ana ayar kapatılırsa tüm alt ayarları da kapat
                    if !enableHapticFeedback {
                        enableNumberInputHaptic = false
                        enableCellTapHaptic = false
                    }
                }) {
                    Image(systemName: enableHapticFeedback ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(enableHapticFeedback ? .blue : .gray)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Sayı girişinde titreşim
            if enableHapticFeedback {
                HStack {
                    Text("Sayı Girişinde Titreşim")
                    Spacer()
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        enableNumberInputHaptic.toggle()
                    }) {
                        Image(systemName: enableNumberInputHaptic ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(enableNumberInputHaptic ? .blue : .gray)
                            .font(.system(size: 24))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.leading, 20) // İç içe görünüm için girintili gösteriyoruz
                .transition(.opacity)
            }
            
            // Hücre seçiminde titreşim
            if enableHapticFeedback {
                HStack {
                    Text("Hücre Seçiminde Titreşim")
                    Spacer()
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        enableCellTapHaptic.toggle()
                    }) {
                        Image(systemName: enableCellTapHaptic ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(enableCellTapHaptic ? .blue : .gray)
                            .font(.system(size: 24))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.leading, 20) // İç içe görünüm için girintili gösteriyoruz
                .transition(.opacity)
            }
            
            // Ses efektleri
            HStack {
                Text("Ses Efektleri")
                Spacer()
                Button(action: {
                    SoundManager.shared.playNavigationSound()
                    enableSoundEffects.toggle()
                }) {
                    Image(systemName: enableSoundEffects ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(enableSoundEffects ? .blue : .gray)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Ses seviyesi kaydırıcısı
            if enableSoundEffects {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Ses Seviyesi")
                        Spacer()
                        Text("\(Int(soundVolume * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.gray)
                        
                        Slider(value: $soundVolume, in: 0...1, step: 0.05)
                            .accentColor(.blue)
                            .onAppear {
                                // İlk yüklemede mevcut değeri SoundManager'a ayarla
                                SoundManager.shared.updateVolumeLevel(soundVolume)
                            }
                            #if os(iOS)
                            .onChange(of: soundVolume) { oldValue, newValue in
                                // AudioServicesPlaySystemSound çağrısı yapmayarak fazladan ses çalmasını engelle
                                SoundManager.shared.updateVolumeLevelQuietly(newValue)
                            }
                            #else
                            .onReceive(Just(soundVolume)) { newValue in
                                // AudioServicesPlaySystemSound çağrısı yapmayarak fazladan ses çalmasını engelle
                                SoundManager.shared.updateVolumeLevelQuietly(newValue)
                            }
                            #endif
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.blue)
                    }
                    
                    // Ses testi butonu
                    Button(action: {
                        SoundManager.shared.executeSound(.test)
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                            Text("Sesi Test Et")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        )
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.leading, 20)
                .transition(.opacity)
            }
            
            // Güç tasarrufu modu
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Güç Tasarrufu Modu")
                    Text("Animasyonları ve görsel efektleri azaltır")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: {
                    SoundManager.shared.playNavigationSound()
                    powerSavingMode.toggle()
                    // PowerSavingManager'ı güncelle
                    PowerSavingManager.shared.isPowerSavingEnabled = powerSavingMode
                }) {
                    Image(systemName: powerSavingMode ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(powerSavingMode ? .green : .gray)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Otomatik güç tasarrufu
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Otomatik Güç Tasarrufu")
                    Text("Pil seviyesi düşükken otomatik olarak etkinleşir")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: {
                    SoundManager.shared.playNavigationSound()
                    autoPowerSaving.toggle()
                    // PowerSavingManager'ı güncelle
                    PowerSavingManager.shared.isAutoPowerSavingEnabled = autoPowerSaving
                }) {
                    Image(systemName: autoPowerSaving ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(autoPowerSaving ? .green : .gray)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Pil durumu göstergesi
            HStack {
                Image(systemName: powerManager.isCharging ? "battery.100.bolt" : getBatteryIcon())
                    .foregroundColor(getBatteryColor())
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pil Durumu: %\(Int(powerManager.batteryLevel * 100))")
                    if powerManager.isCharging {
                        Text("Şarj Oluyor")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if powerManager.batteryLevel <= 0.2 {
                        Text("Düşük Pil")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                if powerManager.batteryLevel <= 0.2 && !powerSavingMode {
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        powerSavingMode = true
                        powerManager.powerSavingMode = true
                    }) {
                        Text("Güç Tasarrufunu Etkinleştir")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.horizontal)
    }
    
    private func appearanceSettingsView() -> some View {
        VStack(spacing: 5) {
            // Sistem görünümünü kullan
            HStack {
                Text("Sistem Görünümünü Kullan")
                Spacer()
                Toggle("", isOn: $themeManager.useSystemAppearance)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Karanlık mod
            if !themeManager.useSystemAppearance {
                HStack {
                    Text("Karanlık Mod")
                    Spacer()
                    Toggle("", isOn: $themeManager.darkMode)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            // Metin boyutu
            VStack(alignment: .leading, spacing: 8) {
                Text("Metin Boyutu")
                
                HStack(spacing: 15) {
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        textSizeString = TextSizePreference.small.rawValue
                    }) {
                        Text("Küçük")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(textSizeString == TextSizePreference.small.rawValue ? Color.blue.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(textSizeString == TextSizePreference.small.rawValue ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(textSizeString == TextSizePreference.small.rawValue ? .blue : .primary)
                    }
                    
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        textSizeString = TextSizePreference.medium.rawValue
                    }) {
                        Text("Orta")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(textSizeString == TextSizePreference.medium.rawValue ? Color.blue.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(textSizeString == TextSizePreference.medium.rawValue ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(textSizeString == TextSizePreference.medium.rawValue ? .blue : .primary)
                    }
                    
                    Button(action: {
                        SoundManager.shared.playNavigationSound()
                        textSizeString = TextSizePreference.large.rawValue
                    }) {
                        Text("Büyük")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(textSizeString == TextSizePreference.large.rawValue ? Color.blue.opacity(0.2) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(textSizeString == TextSizePreference.large.rawValue ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(textSizeString == TextSizePreference.large.rawValue ? .blue : .primary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
        .padding(.horizontal)
    }
    
    private func powerSavingSettingsView() -> some View {
        VStack(spacing: 15) {
            // Güç tasarrufu modu
            HStack {
                Text("Güç Tasarrufu Modu")
                Spacer()
                Toggle("", isOn: $powerSavingMode)
            }
            
            // Otomatik güç tasarrufu
            HStack {
                Text("Otomatik Güç Tasarrufu")
                Spacer()
                Toggle("", isOn: $autoPowerSaving)
            }
        }
        .padding()
    }
    
    private func aboutSettingsView() -> some View {
        VStack(spacing: 20) {
            // Uygulama başlığı ve sürüm bilgisi
            VStack(spacing: 8) {
                Text("Sudoku")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("v1.0")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Geliştirici bilgisi
            VStack(spacing: 8) {
                Text("Geliştirici")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Necati Yıldırım")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            // Görsel ayrım için bir çizgi
            Divider()
                .background(Color.gray.opacity(0.5))
            
            // Ek bilgiler veya bağlantılar
            VStack(spacing: 8) {
                Text("Bu uygulama, benim oynamam için tasarlanmıştır.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("© 2025 Necati Yıldırım")
                    .font(.system(size: 12, weight: .light, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding()
    }
    
    private func aboutView() -> some View {
        VStack(spacing: 15) {
            // Uygulama bilgisi
            VStack(alignment: .leading, spacing: 12) {
                Label("Sudoku App v1.0", systemImage: "app.badge")
                    .font(.headline)
                
                Text("Bu uygulama, Sudoku oynamayı seven herkes için tasarlanmıştır. Kolay, orta, zor ve çok zor seviyelerde oyunlar sunarak her seviyedeki oyuncuya hitap eder.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .padding(.vertical, 8)
                
                HStack(spacing: 12) {
                    Image(systemName: "person.fill.badge.plus")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Geliştirici")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Necati YILDIRIM")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Bağlantılar
            VStack(alignment: .leading, spacing: 12) {
                Text("Bağlantılar")
                    .font(.headline)
                
                websiteLink(url: "https://www.example.com/help", displayText: "Yardım ve Destek")
                
                websiteLink(url: "https://www.example.com/privacy", displayText: "Gizlilik Politikası")
                
                websiteLink(url: "https://www.example.com/contact", displayText: "İletişim")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            // Tüm ayarları sıfırlama butonu
            Button(action: {
                resetAllSettings()
            }) {
                HStack {
                    Spacer()
                    Text("Tüm Ayarları Sıfırla")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                        )
                )
            }
        }
        .padding(.horizontal)
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