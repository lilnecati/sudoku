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
    @AppStorage("soundVolume") private var soundVolume: Double = 0.5
    @AppStorage("enableAchievementNotifications") private var enableAchievementNotifications: Bool = true
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    @AppStorage("prefersDarkMode") private var prefersDarkMode: Bool = false
    @AppStorage("powerSavingMode") private var powerSavingMode: Bool = false
    @AppStorage("autoPowerSaving") private var autoPowerSaving: Bool = true
    @AppStorage("highPerformanceMode") private var highPerformanceMode: Bool = false
    
    // LocalizationManager'a erişim
    @StateObject private var localizationManager = LocalizationManager.shared
    
    // PowerSavingManager'a erişim
    @StateObject private var powerManager = PowerSavingManager.shared
    
    // Dil yönetimi için gerekli değişkenler
    @State private var selectedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "tr"
    
    // Dil seçimi için sheet state değişkeni
    @State private var showLanguageSheet = false
    
    // Başarımlar için sheet state değişkeni
    @State private var showAchievementsSheet = false
    
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
        enableAchievementNotifications = true
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
                        Text.localizedSafe("Profil")
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
        NavigationView {
            ZStack {
                GridBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Profil ve hesap ayarları bölümü - başlık olmadan
                        self.profileSettingsView()

                        // Ayarlar başlığı
                        self.sectionHeader(title: "Oyun Ayarları", systemImage: "gamecontroller.fill")
                        
                        // Oyun ayarları bölümü
                        self.gameSettingsView()
                        
                        // Görünüm ayarları
                        self.sectionHeader(title: "Görünüm", systemImage: "paintbrush.fill")
                        
                        // Görünüm ayarları bölümü - dil seçimi kaldırıldı
                        self.appearanceSettingsView()
                        
                        // Güç tasarrufu ayarları (eğer pil yüzdesi 50'den düşükse ön plana çıkar)
                        if self.powerManager.batteryLevel < 0.5 {
                            self.sectionHeader(title: "Güç Yönetimi", systemImage: "bolt.circle.fill")
                            self.powerSavingSettingsView()
                        } else {
                            self.sectionHeader(title: "Güç Yönetimi", systemImage: "bolt.circle")
                            self.powerSavingSettingsView()
                        }
                        
                        // Alt bilgi
                        VStack(spacing: 5) {
                            Text("Geliştirici: Necati Yıldırım")
                                .scaledFont(size: 14)
                                .foregroundColor(.secondary)
                            
                            Text("Sürüm 1.0")
                                .scaledFont(size: 12)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    }
                    .padding(.top)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitle(Text.localized("settings.title"), displayMode: .large)
            .navigationBarItems(trailing: closeButton)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .localizationAware()
        .preferredColorScheme(themeManager.colorScheme)
        .sheet(isPresented: $showRegisterView) {
            RegisterViewContainer()
        }
        .onAppear {
            // Bildirim dinleyicilerini ayarla
            setupObservers()
            
            // Mevcut kullanıcıyı getir
            currentUser = PersistenceController.shared.getCurrentUser()
            
            // Profil resmini senkronize et
            syncProfileImage()
        }
        .onDisappear {
            // Bildirim dinleyicilerini temizle
            removeObservers()
        }
        .onChange(of: powerManager.batteryLevel) { _, _ in
            // Pil seviyesi değişince arayüzü güncelle
            updateUIOnBatteryChange()
        }
        .onChange(of: themeManager.darkMode) { _, _ in
            // Tema değişikliği olduğunda anında uygulamak için
            themeManager.objectWillChange.send()
        }
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSelectionSheet(
                selectedLanguage: $selectedLanguage,
                localizationManager: localizationManager
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAchievementsSheet) {
            AchievementsSheet()
            .presentationDetents([.medium, .large])
        }
    }
    
    // Bildirim dinleyicilerini ayarla
    private func setupObservers() {
        // Giriş sayfasından kayıt sayfasına geçiş için bildirim dinleyicisi
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowRegisterView"),
            object: nil,
            queue: .main
        ) { _ in
            showRegisterView = true
        }
        
        // Profil resmi güncellendiğinde bildirimi dinle
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ProfileImageUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            // UI'da güncelleme yapmak için mevcut kullanıcı bilgisini yeniden yükle
            self.currentUser = PersistenceController.shared.getCurrentUser()
        }
        
        // Kullanıcı giriş yaptığında senkronizasyonu başlat
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserLoggedIn"),
            object: nil,
            queue: .main
        ) { _ in
            self.syncProfileImage()
        }
    }
    
    // Bildirim dinleyicileri temizle
    private func removeObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ShowRegisterView"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("ProfileImageUpdated"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("UserLoggedIn"),
            object: nil
        )
    }
    
    // Profil resmini senkronize et
    private func syncProfileImage() {
        DispatchQueue.global(qos: .background).async {
            PersistenceController.shared.syncProfileImage { success in
                if success {
                    print("✅ Profil resmi başarıyla senkronize edildi")
                    // Başarılı olduğunda ana thread'de UI güncellemesi yapabiliriz
                    DispatchQueue.main.async {
                        self.currentUser = PersistenceController.shared.getCurrentUser()
                    }
                } else {
                    print("⚠️ Profil resmi senkronizasyonu başarısız oldu veya gereksizdi")
                }
            }
        }
    }
    
    // Pil seviyesi değişince arayüzü güncelle
    private func updateUIOnBatteryChange() {
        // Burada pil durumu değiştiğinde yapılacak işlemler
        // Pil seviyesine göre otomatik güç tasarrufu önerileri vs.
        // Bu fonksiyon onChange(of: powerManager.batteryLevel) içinde çağrılıyor
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
            .fill(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colorScheme == .dark ? 
                            Color.white.opacity(0.15) : 
                            Color.blue.opacity(0.1), 
                            lineWidth: 1)
            )
    }
    
    private func settingRowBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
    }
    
    // Section başlığı yardımcı metodu
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text.localizedSafe(title)
                .font(.title2)
                .bold()
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal, 6)
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
                    
                    Text("Oyun içi ses efektlerini aç/kapat")
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
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
            
            // Ses seviyesi kaydırıcısı - eğer ses açıksa
            // Başarım bildirimleri ayarı
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Başarım Bildirimleri")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    Text("Yeni başarımlar kazanıldığında bildirim göster")
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
                    
                    enableAchievementNotifications.toggle()
                    
                    // Bildirim yöneticisine değişikliği bildir
                    NotificationCenter.default.post(name: Notification.Name("AchievementNotificationSettingChanged"), object: nil)
                }) {
                    ZStack {
                        Capsule()
                            .fill(enableAchievementNotifications ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 55, height: 34)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: enableAchievementNotifications ? 10 : -10)
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: enableAchievementNotifications)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
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
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
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
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
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
                    .animation(nil, value: themeManager.useSystemAppearance)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
            
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
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
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
                    Text.localizedSafe("text.size")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(.primary)
                    
                    // Seçim butonları
                    HStack(spacing: 12) {
                        TextSizeButton(
                            title: "text.size.small",
                            isSelected: textSizeString == TextSizePreference.small.rawValue,
                            action: {
                                updateTextSizePreference(TextSizePreference.small)
                            }
                        )
                        
                        TextSizeButton(
                            title: "text.size.medium", 
                            isSelected: textSizeString == TextSizePreference.medium.rawValue,
                            action: {
                                updateTextSizePreference(TextSizePreference.medium)
                            }
                        )
                        
                        TextSizeButton(
                            title: "text.size.large", 
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
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
        }
    }
    
    struct TextSizeButton: View {
        var title: String
        var isSelected: Bool
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text.localizedSafe(title)
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
    
    struct LanguageButton: View {
        var language: AppLanguage
        var isSelected: Bool
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(language.flag)
                        .font(.system(size: 18))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    Text.localizedSafe("language." + language.code)
                        .scaledFont(size: 15, weight: isSelected ? .semibold : .regular)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? 
                                  LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.15)]), 
                                                startPoint: .topLeading, 
                                                endPoint: .bottomTrailing) : 
                                  LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.05), Color.gray.opacity(0.05)]), 
                                                startPoint: .topLeading, 
                                                endPoint: .bottomTrailing))
                            
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isSelected ? Color.green : Color.gray.opacity(0.4),
                                        isSelected ? Color.green.opacity(0.7) : Color.gray.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                )
                .shadow(color: isSelected ? Color.green.opacity(0.2) : Color.clear, radius: 3, x: 0, y: 1)
                .foregroundColor(isSelected ? .green : .primary)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
                        .fill(getBatteryColor().opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: getBatteryIcon())
                        .font(.system(size: 16))
                        .foregroundColor(getBatteryColor())
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
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
            
            // Güç Tasarrufu Ayarları
            Section {
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
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
                
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
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
                
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
                        Text.localizedSafe("Geliştirici")
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
            }
            .padding(.horizontal, 8)
            
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
            .padding(.horizontal, 8)
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
    
    // Dil değişikliğini işleme fonksiyonu
    private func updateLanguagePreference(_ newValue: AppLanguage) {
        // Mevcut dil değerini al - string olarak
        let previousLanguageCode = localizationManager.currentLanguage
        
        // Değerleri aynıysa erken çık
        guard previousLanguageCode != newValue.code else { return }
        
        // Dili değiştir
        localizationManager.setLanguage(newValue)
        
        // Bildirim sesi çal
        SoundManager.shared.playNavigationSound()
        
        // Görünümün tümünü zorla yenile
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
        
        // Önceki dil kodunu kullanarak dil ismini bul
        let previousLanguageName = AppLanguage.allLanguages.first(where: { $0.code == previousLanguageCode })?.name ?? previousLanguageCode
        
        print("🌐 Dil değiştirildi: \(previousLanguageName) -> \(newValue.name)")
    }
    
    // Profil resmi için eklenen URL'den yükleme fonksiyonu
    private func loadImageFromURL(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else { 
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Profil resmi yüklenemedi: \(error)")
                completion(nil)
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    private func profileSettingsView() -> some View {
        VStack(spacing: 20) {
            // Kullanıcı profil kartı - Büyük ve göze çarpan tasarım
            HStack {
                // Profil resmi
                ZStack {
                    if let user = PersistenceController.shared.getCurrentUser() {
                        // Profil resmi görüntüleme
                        ProfileImageView(user: user)
                            .frame(width: 80, height: 80)
                    } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                .frame(width: 20)
                
                // Kullanıcı bilgileri - Daha kompakt
                VStack(alignment: .leading, spacing: 6) {
                    if let user = PersistenceController.shared.getCurrentUser() {
                        // Giriş yapılmışsa kullanıcı bilgilerini göster
                        Text(user.name ?? "İsimsiz Kullanıcı")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Kullanıcı adını @ işareti ve değiştirilemez ibaresi olmadan göster
                        let displayUsername = user.username ?? ""
                        Text(displayUsername)
                            .onAppear {
                                print("DEBUG - Kullanıcı adı: \(displayUsername)")
                                print("DEBUG - E-posta: \(user.email ?? "")")
                            }
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    } else {
                        // Giriş yapılmamışsa giriş seçenekleri göster
                        Text.localizedSafe("Giriş Yapmadınız")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text.localizedSafe("Skorlarınızı kaydetmek için giriş yapın")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
            )
            
            // Hesap butonu - sadece giriş yapmışsa
            if let _ = PersistenceController.shared.getCurrentUser() {
                // Kullanıcı giriş yapmışsa profil düzenleme ve çıkış butonları
                NavigationLink(destination: ProfileEditView()) {
                    HStack {
                        Label {
                            Text.localizedSafe("profile.edit")
                                .scaledFont(size: 16, weight: .medium)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                
                // Çıkış butonu
                Button(action: {
                    // Çıkış işlemi öncesi debug
                    debugPrint("Çıkış işlemi başlatılıyor, mevcut kullanıcı: \(String(describing: PersistenceController.shared.getCurrentUser()?.username))")
                    
                    // Force UI update first to make sure changes are reflected
                    withAnimation(nil) {
                        // Çıkış işlemi
                        PersistenceController.shared.logoutCurrentUser()
                        
                        // Titreşim ve ses
                        if enableHapticFeedback {
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Başarılı çıkış bildirimi
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    
                    // Çıkış işlemi sonrası debug
                    debugPrint("Çıkış işlemi tamamlandı, mevcut kullanıcı: \(String(describing: PersistenceController.shared.getCurrentUser()?.username))")
                    
                    // UI güncellemesi için garanti mekanizması
                    DispatchQueue.main.async {
                        // Kullanıcı çıkışından sonra veri yenileme bildirimi
                        NotificationCenter.default.post(name: Notification.Name("UserLoggedOut"), object: nil)
                        
                        // Force refresh
                        NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
                        
                        // UI'ı tamamen sıfırlamak için sayfayı kapat
                        self.presentationMode.wrappedValue.dismiss()
                        
                        // Dummy state değişkeni ile görünümü yenileme
                        isRefreshing.toggle()
                    }
                }) {
                    HStack {
                        Label {
                            Text.localizedSafe("Çıkış Yap")
                                .scaledFont(size: 16, weight: .medium)
                                .foregroundColor(.red)
                        } icon: {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.red)
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
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
            } else {
                // Kullanıcı giriş yapmamışsa giriş ve kayıt butonları
                NavigationLink(destination: LoginViewContainer()) {
                    HStack {
                        Label {
                            Text.localizedSafe("Giriş Yap")
                                .scaledFont(size: 16, weight: .medium)
                                .foregroundColor(.blue)
                        } icon: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                
                NavigationLink(destination: RegisterViewContainer()) {
                    HStack {
                        Label {
                            Text.localizedSafe("Yeni Hesap Oluştur")
                                .scaledFont(size: 16, weight: .medium)
                                .foregroundColor(.green)
                        } icon: {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
            }
            
            // Dil Seçimi başlığı
            sectionHeader(title: "Dil Seçimi", systemImage: "globe")
            
            // Dil Seçimi
            VStack(spacing: 20) {
                // Dil seçimi düğmesi
                Button(action: {
                    showLanguageSheet = true
                }) {
                    HStack(spacing: 15) {
                        // İkon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "globe")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        
                        // Başlık ve açıklama
                        VStack(alignment: .leading, spacing: 4) {
                            Text.localizedSafe("language.selection")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.primary)
                            
                            Text(AppLanguage.allLanguages.first(where: { $0.code == selectedLanguage })?.name ?? "Türkçe")
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            
            // Başarımlar başlığı
            sectionHeader(title: "Başarımlar", systemImage: "trophy.fill")
            
            // Başarımlar Bölümü
            VStack(spacing: 20) {
                // Başarımlar düğmesi
                Button(action: {
                    showAchievementsSheet = true
                }) {
                    HStack(spacing: 15) {
                        // İkon
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.yellow)
                        }
                        
                        // Başlık ve açıklama
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Başarımlar")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.primary)
                            
                            Text("Tüm başarımlarınızı görüntüleyin")
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Başarımları sıfırlama düğmesi
                Button(action: {
                    resetAchievementData()
                }) {
                    HStack(spacing: 15) {
                        // İkon
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                        
                        // Başlık ve açıklama
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Başarımları Sıfırla")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.red)
                            
                            Text("Tüm başarımları sıfırlayın")
                                .scaledFont(size: 13)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
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
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
        }
    }
    
    private var mainSettingsView: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Profil ve hesap ayarları bölümü - başlık olmadan
                self.profileSettingsView()

                // Ayarlar başlığı
                self.sectionHeader(title: "Oyun Ayarları", systemImage: "gamecontroller.fill")
                
                // Oyun ayarları bölümü
                self.gameSettingsView()
                
                // Görünüm ayarları
                self.sectionHeader(title: "Görünüm", systemImage: "paintbrush.fill")
                
                // Görünüm ayarları bölümü - dil seçimi kaldırıldı
                self.appearanceSettingsView()
                
                // Güç tasarrufu ayarları (eğer pil yüzdesi 50'den düşükse ön plana çıkar)
                if self.powerManager.batteryLevel < 0.5 {
                    self.sectionHeader(title: "Güç Yönetimi", systemImage: "bolt.circle.fill")
                    self.powerSavingSettingsView()
                } else {
                    self.sectionHeader(title: "Güç Yönetimi", systemImage: "bolt.circle")
                    self.powerSavingSettingsView()
                }
                
                // Alt bilgi
                VStack(spacing: 5) {
                    Text("Geliştirici: Necati Yıldırım")
                        .scaledFont(size: 14)
                        .foregroundColor(.secondary)
                    
                    Text("Sürüm 1.0")
                        .scaledFont(size: 12)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 30)
                .padding(.bottom, 20)
            }
            .padding(.top)
            .padding(.horizontal, 16)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var closeButton: some View {
        Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }) {
            Text("Tamam")
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
    
    // Başarı verilerini sıfırlayan fonksiyon
    private func resetAchievementData() {
        let userDefaults = UserDefaults.standard
        let achievementsKey = "user_achievements"
        let streakKey = "user_streak_data"
        
        // Başarı verilerini sil
        userDefaults.removeObject(forKey: achievementsKey)
        userDefaults.removeObject(forKey: streakKey)
        
        // Günlük oyun sayısı verilerini de sil
        let calendar = Calendar.current
        for i in -7...7 { // Son 7 gün ve gelecek 7 gün
            let date = calendar.date(byAdding: .day, value: i, to: Date()) ?? Date()
            let dayKey = "daily_completions_\(calendar.startOfDay(for: date).timeIntervalSince1970)"
            userDefaults.removeObject(forKey: dayKey)
        }
        
        // Gece Kuşu ve Erken Kuş başarıları için verileri sil
        userDefaults.removeObject(forKey: "night_owl_progress")
        userDefaults.removeObject(forKey: "early_bird_progress")
        userDefaults.removeObject(forKey: "weekend_warrior_progress")
        
        // AchievementManager'ı yeniden başlatmak için bildirim gönder
        NotificationCenter.default.post(name: Notification.Name("ResetAchievements"), object: nil)
        
        print("🧹 Tüm başarı verileri silindi")
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
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 6)
    }
}

// Dil seçimi sayfası
struct LanguageSelectionSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedLanguage: String
    @ObservedObject var localizationManager: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            ZStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .padding(.leading)
                    
                    Spacer()
                }
                
                Text.localizedSafe("language.selection")
                    .scaledFont(size: 17, weight: .bold)
                    .padding()
            }
            .padding(.top, 8)
            .background(
                colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
            )
            
            Divider()
            
            // Dil listesi
            ScrollView {
                VStack(spacing: 15) {
                    // Aktif diller
                    LanguageCell(
                        flag: "🇹🇷",
                        languageName: "Türkçe",
                        isSelected: selectedLanguage == "tr",
                        action: {
                            localizationManager.setLanguage(AppLanguage(code: "tr", name: "Türkçe"))
                            selectedLanguage = "tr"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                    
                    LanguageCell(
                        flag: "🇬🇧",
                        languageName: "English",
                        isSelected: selectedLanguage == "en",
                        action: {
                            localizationManager.setLanguage(AppLanguage(code: "en", name: "English"))
                            selectedLanguage = "en"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                    
                    LanguageCell(
                        flag: "🇫🇷",
                        languageName: "Français",
                        isSelected: selectedLanguage == "fr",
                        isDisabled: false,
                        action: {
                            localizationManager.setLanguage(AppLanguage(code: "fr", name: "Français"))
                            selectedLanguage = "fr"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                    
                    // Yakında eklenecek diller
                    Group {
                        Text.localizedSafe("coming.soon.languages")
                            .scaledFont(size: 12)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LanguageCell(
                            flag: "🇪🇸",
                            languageName: "Español",
                            isSelected: false,
                            isDisabled: true,
                            action: {}
                        )
                        
                        LanguageCell(
                            flag: "🇩🇪",
                            languageName: "Deutsch",
                            isSelected: false,
                            isDisabled: true,
                            action: {}
                        )
                        
                        LanguageCell(
                            flag: "🇮🇹",
                            languageName: "Italiano",
                            isSelected: false,
                            isDisabled: true,
                            action: {}
                        )
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 16)
            }
        }
        .background(colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Dil hücreleri
struct LanguageCell: View {
    var flag: String
    var languageName: String
    var isSelected: Bool
    var isDisabled: Bool = false
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(flag)
                    .font(.system(size: 34))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 5)
                
                Text(languageName)
                    .scaledFont(size: 20, weight: isSelected ? .semibold : .regular)
                    .foregroundColor(isDisabled ? .gray : (isSelected ? .primary : .primary))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 22))
                        .padding(.trailing, 5)
                }
                
                if isDisabled {
                    Text.localizedSafe("coming.soon")
                        .scaledFont(size: 12)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                        )
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected ? 
                        (colorScheme == .dark ? 
                         Color(.systemGray5).opacity(0.8) : 
                         Color.green.opacity(0.08)) :
                        (colorScheme == .dark ? 
                         Color(.systemGray6) : 
                         Color.white)
                    )
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.1 : 0.05),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: isSelected ? 2 : 1
                    )
            )
        }
        .disabled(isDisabled)
        .buttonStyle(PlainButtonStyle())
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// Profil resmi görüntüleme bileşeni
struct ProfileImageView: View {
    let user: User
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Arka plan daire
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            
            if isLoading {
                // Yükleniyor göstergesi
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let image = profileImage {
                // Profil resmi
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            } else {
                // Varsayılan avatar - baş harfler
                Text(String(user.name?.prefix(1) ?? "U"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadProfileImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileImageUpdated"))) { _ in
            print("📢 Profil resmi güncelleme bildirimi alındı")
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        // Resmin yüklenme zamanını ekle
        let loadTime = Date()
        print("🕒 Profil resmi yükleme başladı: \(loadTime)")
        
        // Önbellekteki resimleri temizle (cihaz-simülatör arasındaki farklılıkları önlemek için)
        URLCache.shared.removeAllCachedResponses()
        
        // Önce yerel depolamada kontrol et
        if let imageData = user.profileImage, let image = UIImage(data: imageData) {
            profileImage = image
            print("✅ Profil resmi yerel depolamadan yüklendi - Boyut: \(imageData.count) byte, Hash: \(imageData.hashValue)")
            return
        }
        
        // Yerel yoksa URL'den yüklemeyi dene
        if let photoURL = user.photoURL {
            isLoading = true
            print("🔄 Profil resmi URL'den yükleniyor: \(photoURL)")
            
            guard let url = URL(string: photoURL) else {
                isLoading = false
                print("❌ Geçersiz profil resmi URL'si: \(photoURL)")
                return
            }
            
            // Önbellek politikası - yeniden yüklemeyi zorla
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("❌ Profil resmi yükleme hatası: \(error)")
                        return
                    }
                    
                    if let response = response as? HTTPURLResponse {
                        print("📡 URL yanıt kodu: \(response.statusCode)")
                    }
                    
                    if let data = data, let image = UIImage(data: data) {
                        print("✅ Profil resmi URL'den başarıyla yüklendi - Boyut: \(data.count) byte, Hash: \(data.hashValue)")
                        self.profileImage = image
                        
                        // Resmi yerel olarak da kaydet
                        self.user.profileImage = data
                        // Not: Burada zaman damgası ekleyecektik fakat User modelinde lastProfileUpdate özelliği yok
                        do {
                            try PersistenceController.shared.container.viewContext.save()
                            UserDefaults.standard.synchronize() // Hemen senkronize et
                            print("✅ Profil resmi yerel veritabanına kaydedildi")
                            
                            // Tüm profil resmi görünümlerini güncellemek için bildirim gönder
                            NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
                        } catch {
                            print("❌ Profil resmi yerel olarak kaydedilemedi: \(error)")
                        }
                    } else {
                        print("❌ Profil resmi verisi dönüştürülemedi")
                    }
                }
            }.resume()
        } else {
            print("ℹ️ Kullanıcının profil resmi URL'si yok")
        }
    }
}
