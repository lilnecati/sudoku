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
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    // Dismiss için Binding
    @Binding var showView: Bool
    
    // Init fonksiyonu ekleyelim
    init(showView: Binding<Bool>) {
        self._showView = showView
    }
    
    // Default initializer (mevcut showView Binding olmadan)
    init() {
        // Geçici bir @State değişkeni oluştur çünkü Binding gerekli
        self._showView = .constant(true)
    }
    
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
    
    // Tahta rengi seçimi için sheet state değişkeni
    @State private var showBoardColorSheet = false
    
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

    // Profil düzenleme sheet'ini kontrol etmek için state
    @State private var showProfileEditSheet = false

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
                    gradient: Gradient(colors: isBejMode ? 
                                      [ThemeManager.BejThemeColors.accent, ThemeManager.BejThemeColors.accent.opacity(0.7)] : 
                                      [.blue, .purple]),
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
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue)
                    .cornerRadius(12)
                    .shadow(color: (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue).opacity(0.3), radius: 5, x: 0, y: 2)
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
                    .fill(isBejMode ? 
                        ThemeManager.BejThemeColors.cardBackground : 
                        (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
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
            ZStack {
            // GridBackgroundView tam ekranı kaplasın
                GridBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) { // Ana VStack spacing 0
                // Özel Başlık Çubuğu
                HStack {
                    Text("Ayarlar") // Başlık metni
                        .font(.largeTitle.bold())
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Spacer()
                    
                    // "Tamam" butonu kaldırıldı
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // İçerik ScrollView'ı
                ScrollView {
                    VStack(spacing: 15) { 
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
                        .padding(.top, 15) 
                        .padding(.bottom, 10) 
                    }
                    .padding(.top, 8) 
                    .padding(.horizontal, 16)
                }
            }
        }
        .localizationAware()
        .preferredColorScheme(themeManager.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: themeManager.darkMode)
        .animation(.easeInOut(duration: 0.3), value: themeManager.useSystemAppearance)
        .themeAware()
        .sheet(isPresented: $showRegisterView) {
            RegisterView(isPresented: $showRegisterView, currentUser: $currentUser)
        }
        .sheet(isPresented: $showLoginView) {
            LoginView(isPresented: $showLoginView, currentUser: $currentUser)
        }
        // Yeni sheet modifier: ProfileEditView için
        .sheet(isPresented: $showProfileEditSheet) {
            // ProfileEditView'ı burada çağırıyoruz.
            // ProfileEditView'ın mevcut kullanıcıyı alması gerekebilir.
            if let user = currentUser ?? PersistenceController.shared.getCurrentUser() {
                 ProfileEditView(user: user, isPresented: $showProfileEditSheet)
                    .environmentObject(themeManager) // Gerekliyse themeManager'ı da geçirelim
            } else {
                // Kullanıcı bulunamazsa bir hata mesajı veya boş görünüm gösterilebilir
                Text("Profil düzenlenemiyor. Kullanıcı bulunamadı.")
            }
        }
        .onAppear {
            // Ekran kararması yönetimi SudokuApp'a devredildi
            // loadSettings() // Bu satır kaldırıldı

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
            
            // Tema değişimi geri bildirimi
            if enableHapticFeedback {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeChanged"))) { notification in
            // Tema değişikliği bildirimini alınca görünümü güncelle
            withAnimation(.easeInOut(duration: 0.3)) {
                // Görünümü güncellemek için boş bir işlem - SwiftUI bunu algılayıp yeniden çizer
                let _ = themeManager.colorScheme
            }
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
        .sheet(isPresented: $showBoardColorSheet) {
            AppearanceSettingsSheet()
                .environmentObject(themeManager)
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
        
        // Tema değişikliği bildirimi dinleyicisi
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ThemeChanged"),
            object: nil,
            queue: .main
        ) { notification in
            // Tema değişikliğinde görsel geri bildirim
            if self.enableHapticFeedback {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.5)
            }
            
            // Log kaydı
            if let isDarkMode = notification.userInfo?["isDarkMode"] as? Bool {
                logInfo("Tema değişimi algılandı: \(isDarkMode ? "Koyu" : "Açık") mod")
            } else if let useSystem = notification.userInfo?["useSystemAppearance"] as? Bool {
                logInfo("Sistem teması kullanımı değişimi algılandı: \(useSystem ? "Aktif" : "Pasif")")
            }
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
                    logSuccess("Profil resmi başarıyla senkronize edildi")
                    // Başarılı olduğunda ana thread'de UI güncellemesi yapabiliriz
                    DispatchQueue.main.async {
                        self.currentUser = PersistenceController.shared.getCurrentUser()
                    }
                } else {
                    logWarning("Profil resmi senkronizasyonu başarısız oldu veya gereksizdi")
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
            .fill(isBejMode ? 
                 ThemeManager.BejThemeColors.cardBackground : 
                 Color(uiColor: UIColor.systemBackground).opacity(0.8))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isBejMode ? 
                           ThemeManager.BejThemeColors.accent.opacity(0.2) : 
                           (colorScheme == .dark ? 
                            Color.white.opacity(0.15) : 
                            Color.blue.opacity(0.1)), 
                            lineWidth: 1)
            )
    }
    
    private func settingRowBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isBejMode ? 
                 ThemeManager.BejThemeColors.cardBackground : 
                 Color(uiColor: UIColor.systemBackground).opacity(0.8))
            .shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isBejMode ? 
                           ThemeManager.BejThemeColors.accent.opacity(0.2) : 
                           Color.blue.opacity(0.2), lineWidth: 1)
            )
    }
    
    // Section başlığı yardımcı metodu
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
            
            Text.localizedSafe(title)
                .font(.title2)
                .bold()
                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.accent.opacity(0.1) : 
                     Color.blue.opacity(0.1))
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
                        .fill(isBejMode ?
                             ThemeManager.BejThemeColors.accent.opacity(0.15) :
                             Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ses Efektleri")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Text("Oyun içi ses efektlerini aç/kapat")
                        .scaledFont(size: 13)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
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
                            .fill(enableSoundEffects ? 
                                 (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue) : 
                                 Color.gray.opacity(0.3))
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
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 8)
            
            // Ses seviyesi kaydırıcısı - eğer ses açıksa
            // Başarım bildirimleri ayarı
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.accent.opacity(0.15) : 
                             Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .purple)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Başarım Bildirimleri")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Text("Yeni başarımlar kazanıldığında bildirim göster")
                        .scaledFont(size: 13)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
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
                            .fill(enableAchievementNotifications ? 
                                 (isBejMode ? ThemeManager.BejThemeColors.accent : Color.purple) : 
                                 Color.gray.opacity(0.3))
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
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
            
            // Haptic feedback ayarı
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.accent.opacity(0.15) : 
                             Color.green.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .green)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Titreşim Geri Bildirimi")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Text("Dokunmatik geri bildirim ve haptik motor kullanımı")
                        .scaledFont(size: 13)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Toggle butonu
                Button(action: {
                    // Titreşim kontrolü - kapatmadan önce son bir geri bildirim
                        SoundManager.shared.playNavigationSoundOnly()
                    
                    if enableHapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred(intensity: 0.8)
                    }
                    
                    enableHapticFeedback.toggle()
                }) {
                    ZStack {
                        Capsule()
                            .fill(enableHapticFeedback ? 
                                 (isBejMode ? ThemeManager.BejThemeColors.accent : Color.green) : 
                                 Color.gray.opacity(0.3))
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
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         Color(uiColor: UIColor.systemBackground).opacity(0.8))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
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
                                .fill(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.15) : Color.yellow.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                            Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .yellow)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                            Text("Başarımlar")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                            Text("Tüm başarımlarınızı görüntüleyin")
                        .scaledFont(size: 13)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .gray)
                    }
                    .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                            .fill(isBejMode ? ThemeManager.BejThemeColors.cardBackground : (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
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
                                .fill(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.15) : Color.red.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                            Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16))
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .red)
                    }
                    
                    // Başlık ve açıklama
                    VStack(alignment: .leading, spacing: 4) {
                            Text("Başarımları Sıfırla")
                            .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .red)
                        
                            Text("Tüm başarımları sıfırlayın")
                            .scaledFont(size: 13)
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                            .fill(isBejMode ? ThemeManager.BejThemeColors.cardBackground : (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
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
        .background(Color(uiColor: UIColor.systemBackground).opacity(0.95))
        .cornerRadius(20)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        }
    
    private var closeButton: some View {
        Button(action: {
            // presentationMode çağrısı yerine doğrudan showView'ı false yapıyoruz
            self.showView = false
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
        
        logInfo("Tüm başarı verileri silindi")
    }
    
    private func getColorNameFromCode(_ colorCode: String) -> String {
        switch colorCode {
        case "red":
            return "Kırmızı"
        case "pink":
            return "Pembe"
        case "orange":
            return "Turuncu"
        case "purple":
            return "Mor"
        case "green":
            return "Yeşil"
        default:
            return "Mavi"
        }
    }
    
    // Görünüm ayarları görünümü için fonksiyon
    private func appearanceSettingsView() -> some View {
        Button(action: {
            showBoardColorSheet = true
        }) {
            HStack(spacing: 15) {
                // İkon
                ZStack {
                    Circle()
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.accent.opacity(0.15) : 
                             Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .purple)
                }
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 4) {
                    Text("Görünüm Ayarları")
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    
                    Text("Temalar ve renk seçenekleri")
                        .scaledFont(size: 13)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
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
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
    }
    
    // Güç tasarrufu ayarları görünümü için fonksiyon
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
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
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
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
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
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .yellow)
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
                                .fill(highPerformanceMode ? 
                                     (isBejMode ? ThemeManager.BejThemeColors.accent : Color.yellow) : 
                                     Color.gray.opacity(0.3))
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
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.cardBackground : 
                             (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
                
                // Otomatik güç tasarrufu
                HStack {
                    Label {
                        Text("Otomatik Güç Tasarrufu")
                            .scaledFont(size: 16, weight: .medium)
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    } icon: {
                        Image(systemName: "battery.25")
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .orange)
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
                                .fill(autoPowerSaving ? 
                                     (isBejMode ? ThemeManager.BejThemeColors.accent : Color.orange) : 
                                     Color.gray.opacity(0.3))
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
                        .fill(isBejMode ? 
                             ThemeManager.BejThemeColors.cardBackground : 
                             (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 8)
                
                // Güç tasarrufu açıklaması
                if powerSavingMode || autoPowerSaving {
                    Text("Güç tasarrufu modu, bazı görsel efektleri ve animasyonları devre dışı bırakır veya basitleştirir.")
                        .scaledFont(size: 12)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                }
                
                // Yüksek performans açıklaması
                if highPerformanceMode {
                    Text("Yüksek performans modu daha akıcı animasyonlar ve görsel efektler sağlar ancak pil kullanımını artırır.")
                        .scaledFont(size: 12)
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                }
            } header: {
                Text("Performans")
                    .scaledFont(size: 18, weight: .bold)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                    .padding(.horizontal, 8)
            } footer: {
                Text("Güç tasarrufu modu, cihazınızın pil ömrünü uzatır.")
                    .scaledFont(size: 12)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
            .padding(.horizontal, 8)
            }
        }
    }
    
    // Profil ayarları görünümü
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
                
                // Kullanıcı bilgileri
                VStack(alignment: .leading, spacing: 6) {
                    if let user = PersistenceController.shared.getCurrentUser() {
                        // Giriş yapılmışsa kullanıcı bilgilerini göster
                        Text(user.value(forKey: "name") as? String ?? "İsimsiz Kullanıcı")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                        
                        // Kullanıcı adı
                        let displayUsername = user.value(forKey: "username") as? String ?? ""
                        Text(displayUsername)
                            .font(.system(size: 16))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                    } else {
                        // Giriş yapılmamışsa
                        Text.localizedSafe("Giriş Yapmadınız")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                        
                        Text.localizedSafe("Skorlarınızı kaydetmek için giriş yapın")
                            .font(.system(size: 16))
                            .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                         (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
            )
            
            // Butonlar - giriş durumuna göre farklı butonlar göster
            if PersistenceController.shared.getCurrentUser() != nil { // Sadece varlığını kontrol et
                // Kullanıcı giriş yapmışsa - Profili Düzenle ve Çıkış Yap butonları
                HStack(spacing: 12) {
                    // Profili Düzenle butonu -> NavigationLink yerine sheet açacak
                    Button(action: {
                        // Titreşim geri bildirimi
                        if enableHapticFeedback {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Profil düzenleme sheet'ini aç
                        showProfileEditSheet = true 
                        logInfo("Profil düzenleme butonu tıklandı, sheet açılıyor")
                    }) {
                        HStack {
                            Image(systemName: "person.fill.badge.plus")
                                .font(.system(size: 16))
                            Text("Profili Düzenle")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                            (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue)
                                .cornerRadius(12)
                                .shadow(color: (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue).opacity(0.3), radius: 5, x: 0, y: 2)
                    )
                }
                
                    // Çıkış Yap butonu
                Button(action: {
                        // Titreşim geri bildirimi
                        if enableHapticFeedback {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Çıkış yap
                        logoutUser()
                }) {
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
            } else {
                // Kullanıcı giriş yapmamışsa - Giriş Yap ve Kayıt Ol butonları
                VStack(spacing: 12) {
                    // Giriş Yap butonu
                    Button(action: {
                        // Titreşim geri bildirimi
                        if enableHapticFeedback {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
            }
            
                        // Giriş sayfasına yönlendir
                        showLoginView = true
                        logInfo("Giriş yap butonu tıklandı")
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                            Text("Giriş Yap")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    .background(
                            (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue)
                                .cornerRadius(12)
                                .shadow(color: (isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue).opacity(0.3), radius: 5, x: 0, y: 2)
                    )
                }
                    
                    // Kayıt Ol butonu
                Button(action: {
                        // Titreşim geri bildirimi
                        if enableHapticFeedback {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            SoundManager.shared.playNavigationSound()
                        } else {
                            SoundManager.shared.playNavigationSoundOnly()
                        }
                        
                        // Kayıt sayfasına yönlendir
                        showRegisterView = true
                        logInfo("Kayıt ol butonu tıklandı")
                }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                            Text("Kayıt Ol")
                                .scaledFont(size: 16, weight: .medium)
                        }
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isBejMode ? ThemeManager.BejThemeColors.accent : Color.blue, lineWidth: 1)
                                )
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                }
                }
            }
        }
    }
    
    // Kullanıcı çıkış işlemi için fonksiyon
    private func logoutUser() {
        // Çıkış işlemleri
        PersistenceController.shared.logoutCurrentUser()
        
        // UI güncellemesi ana thread'de yapılmalı
        DispatchQueue.main.async {
            // Kullanıcı bilgisini sıfırla
            self.currentUser = nil
            
            // Bildirim gönder
            NotificationCenter.default.post(name: Notification.Name("UserLoggedOut"), object: nil)
        }
        
        logSuccess("Kullanıcı başarıyla çıkış yaptı")
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
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
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
                    .foregroundColor(isDisabled ? .gray : (isBejMode ? ThemeManager.BejThemeColors.text : .primary))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : .green)
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
                        (isBejMode ? 
                         ThemeManager.BejThemeColors.accent.opacity(0.08) : 
                        (colorScheme == .dark ? 
                         Color(.systemGray5).opacity(0.8) : 
                          Color.green.opacity(0.08))) :
                        (isBejMode ? 
                         ThemeManager.BejThemeColors.cardBackground : 
                        (colorScheme == .dark ? 
                         Color(.systemGray6) : 
                          Color.white))
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
    let user: NSManagedObject
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        ZStack {
            // Arka plan daire
            Circle()
                .fill(
                    isBejMode ?
                    LinearGradient(
                        gradient: Gradient(colors: [ThemeManager.BejThemeColors.accent.opacity(0.7), ThemeManager.BejThemeColors.accent.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.3) : Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            
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
                                isBejMode ?
                                LinearGradient(
                                    gradient: Gradient(colors: [ThemeManager.BejThemeColors.accent.opacity(0.7), ThemeManager.BejThemeColors.accent.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
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
                Text(String((user.value(forKey: "name") as? String ?? "U").prefix(1)))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadProfileImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileImageUpdated"))) { _ in
            logInfo("Profil resmi güncelleme bildirimi alındı")
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        // Resmin yüklenme zamanını ekle
        let loadTime = Date()
        logInfo("Profil resmi yükleme başladı: \(loadTime)")
        
        // Önbellekteki resimleri temizle (cihaz-simülatör arasındaki farklılıkları önlemek için)
        URLCache.shared.removeAllCachedResponses()
        
        // Önce yerel depolamada kontrol et
        if let imageData = user.value(forKey: "profileImage") as? Data, let image = UIImage(data: imageData) {
            profileImage = image
            logSuccess("Profil resmi yerel depolamadan yüklendi - Boyut: \(imageData.count) byte, Hash: \(imageData.hashValue)")
            return
        }
        
        // Yerel yoksa URL'den yüklemeyi dene
        if let photoURL = user.value(forKey: "photoURL") as? String {
            isLoading = true
            logInfo("Profil resmi URL'den yükleniyor: \(photoURL)")
            
            guard let url = URL(string: photoURL) else {
                isLoading = false
                logError("Geçersiz profil resmi URL'si: \(photoURL)")
                return
            }
            
            // Önbellek politikası - yeniden yüklemeyi zorla
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        logError("Profil resmi yükleme hatası: \(error)")
                        return
                    }
                    
                    if let response = response as? HTTPURLResponse {
                        logInfo("URL yanıt kodu: \(response.statusCode)")
                    }
                    
                    if let data = data, let image = UIImage(data: data) {
                        logSuccess("Profil resmi URL'den başarıyla yüklendi - Boyut: \(data.count) byte, Hash: \(data.hashValue)")
                        self.profileImage = image
                        
                        // Resmi yerel olarak da kaydet
                        self.user.setValue(data, forKey: "profileImage")
                        do {
                            try PersistenceController.shared.container.viewContext.save()
                            logSuccess("Profil resmi veritabanına kaydedildi")
                        } catch {
                            logError("Profil resmi kaydedilemedi: \(error)")
                        }
                    } else {
                        logError("Profil resmi verisi alınamadı")
                    }
                }
            }.resume()
        }
    }
}

// Tahta renk seçimi sayfası
struct AppearanceSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("textSizePreference") private var textSizeString = TextSizePreference.medium.rawValue
    
    // Renk seçildiğinde animasyon için
    @State private var selectedColorAnimated: String? = nil
    // Tema değişimi için animasyon durumları
    @State private var darkModeAnimation: Bool = false
    @State private var systemAppearanceAnimation: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Başlık
                    Text("Görünüm Ayarları")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Tema ayarları başlığı
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("Uygulama Teması")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Tema önizleme kartı
                    themePreviewCard
                        .padding(.horizontal)
                    
                    // NOT: "Sistem Görünümünü Kullan" ve "Koyu Mod" butonları kaldırıldı
                    // Tema kartları üzerinden doğrudan tema değişikliği yapılabilir
                    
                    // Metin boyutu
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 15) {
                            // İkon
                            ZStack {
                                Circle()
                                    .fill(themeManager.bejMode ? ThemeManager.BejThemeColors.accent.opacity(0.15) : Color.orange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "textformat.size")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeManager.bejMode ? ThemeManager.BejThemeColors.accent : .orange)
                            }
                            
                            Text("Metin Boyutu")
                                .font(.headline)
                                .foregroundColor(themeManager.bejMode ? ThemeManager.BejThemeColors.text : .primary)
                        }
                        
                        // Seçim butonları
                        HStack(spacing: 12) {
                            ForEach(TextSizePreference.allCases, id: \.self) { size in
                                Button(action: {
                                    updateTextSizePreference(size)
                                }) {
                                    VStack(spacing: 8) {
                                        Text("A")
                                            .font(.system(size: size.scaleFactor * 24))
                                            .fontWeight(.bold)
                                            .foregroundColor(textSizeString == size.rawValue ? 
                                                            (themeManager.bejMode ? ThemeManager.BejThemeColors.background : .white) : 
                                                            (themeManager.bejMode ? ThemeManager.BejThemeColors.text : .primary))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(textSizeString == size.rawValue ? 
                                                         (themeManager.bejMode ? ThemeManager.BejThemeColors.accent : Color.orange) : 
                                                         Color.clear)
                                                    .overlay(
                                                        Circle()
                                                            .strokeBorder(themeManager.bejMode ? 
                                                                          ThemeManager.BejThemeColors.accent.opacity(0.5) : 
                                                                          Color.orange.opacity(0.5), 
                                                                        lineWidth: textSizeString == size.rawValue ? 0 : 1)
                                                    )
                                            )
                                        
                                        Text.localizedSafe(size.rawValue)
                                            .font(.system(size: 14))
                                            .foregroundColor(textSizeString == size.rawValue ? 
                                                           (themeManager.bejMode ? ThemeManager.BejThemeColors.accent : .orange) : 
                                                           (themeManager.bejMode ? ThemeManager.BejThemeColors.secondaryText : .primary))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.bejMode ? ThemeManager.BejThemeColors.cardBackground : 
                                 (colorScheme == .dark ? Color(.systemGray6) : Color.white))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    
                    // Sudoku Tahtası Renk Seçimi
                    VStack {
                        // Başlık kısmı
                        HStack {
                            // İkon ve renk önizlemesi
                            ZStack {
                                Circle()
                                    .fill(themeManager.getBoardColor().opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "square.grid.3x3.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeManager.getBoardColor())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sudoku Tahtası Rengi")
                                    .font(.headline)
                                    .foregroundColor(themeManager.bejMode ? 
                                                     ThemeManager.BejThemeColors.text : 
                                                     .primary)
                                
                                Text("Şu anki: \(themeManager.getBoardColorName())")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.bejMode ? 
                                                    ThemeManager.BejThemeColors.secondaryText : 
                                                    .secondary)
                            }
                            
                            Spacer()
                            
                            // Mevcut renk önizlemesi
                            Circle()
                                .fill(themeManager.getBoardColor())
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0)
                                )
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Açıklama
                        Text("Tahta rengini, seçili hücreleri ve kullanıcı girdilerini renklendirir")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        
                        // Renk ızgarası - 2x3 düzeni
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            // Renk seçenekleri
                            colorButton(color: .blue, name: "Mavi", code: "blue")
                            colorButton(color: .red, name: "Kırmızı", code: "red")
                            colorButton(color: .pink, name: "Pembe", code: "pink")
                            colorButton(color: .orange, name: "Turuncu", code: "orange")
                            colorButton(color: .purple, name: "Mor", code: "purple")
                            colorButton(color: .green, name: "Yeşil", code: "green")
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.bejMode ? 
                                  ThemeManager.BejThemeColors.cardBackground : 
                                  (colorScheme == .dark ? Color(.systemGray6) : Color.white))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .background(themeManager.bejMode ? 
                   ThemeManager.BejThemeColors.background : 
                   (colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.7)))
            .navigationBarItems(trailing: Button("Tamam") {
                // Değişiklikleri kaydetmek için nesneyi değişmiş olarak işaretle
                themeManager.objectWillChange.send()
                
                // Tema değişikliği bildirimini gönder
                NotificationCenter.default.post(
                    name: NSNotification.Name("ThemeChanged"), 
                    object: nil
                )
                
                // Sayfayı kapat
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Mevcut rengi animasyon için kaydet
                selectedColorAnimated = themeManager.sudokuBoardColor
                
                // Mevcut tema değerlerini eşitle
                darkModeAnimation = themeManager.darkMode
                systemAppearanceAnimation = themeManager.useSystemAppearance
            }
            .preferredColorScheme(themeManager.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: themeManager.darkMode)
            .animation(.easeInOut(duration: 0.3), value: themeManager.useSystemAppearance)
        }
    }
    
    // Tema önizleme kartı
    private var themePreviewCard: some View {
        VStack(spacing: 12) {
            // Başlık
            Text("Geçerli Tema")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            // Önizleme kutucukları
            HStack(spacing: 10) {
                // Koyu mod önizleme
                themeSampleCard(
                    title: "Koyu Mod", 
                    isSelected: themeManager.darkMode && !themeManager.useSystemAppearance && !themeManager.bejMode,
                    isDarkMode: true
                )
                .onTapGesture {
                    if enableHapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.updateAppTheme(darkMode: true, useSystemAppearance: false, bejMode: false)
                    }
                }
                
                // Açık mod önizleme
                themeSampleCard(
                    title: "Açık Mod", 
                    isSelected: !themeManager.darkMode && !themeManager.useSystemAppearance && !themeManager.bejMode,
                    isDarkMode: false
                )
                .onTapGesture {
                    if enableHapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.updateAppTheme(darkMode: false, useSystemAppearance: false, bejMode: false)
                    }
                }
                
                // Sistem modu önizleme
                themeSampleCard(
                    title: "Sistem", 
                    isSelected: themeManager.useSystemAppearance && !themeManager.bejMode,
                    isDarkMode: UITraitCollection.current.userInterfaceStyle == .dark
                )
                .onTapGesture {
                    if enableHapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.updateAppTheme(useSystemAppearance: true, bejMode: false)
                    }
                }
                
                // Bej mod önizleme
                themeSampleCard(
                    title: "Bej Mod", 
                    isSelected: themeManager.bejMode,
                    isDarkMode: false,
                    isBejMode: true
                )
                .onTapGesture {
                    if enableHapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.updateAppTheme(bejMode: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.bejMode ? 
                      ThemeManager.BejThemeColors.cardBackground : 
                      (colorScheme == .dark ? Color(.systemGray6) : Color.white))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // Tema örnek kartı
    private func themeSampleCard(title: String, isSelected: Bool, isDarkMode: Bool, isBejMode: Bool = false) -> some View {
        VStack(spacing: 8) {
            // Örnek görünüm
            VStack(spacing: 4) {
                // Renk ayarları
                let barColor = isBejMode ? ThemeManager.BejThemeColors.background : (isDarkMode ? Color.black : Color.white)
                let contentColor = isBejMode ? ThemeManager.BejThemeColors.cardBackground : (isDarkMode ? Color.black : Color.white)
                let textColor = isBejMode ? ThemeManager.BejThemeColors.secondaryText : (isDarkMode ? Color.gray.opacity(0.7) : Color.gray.opacity(0.3))
                
                // Uygulama çubuğu
                Rectangle()
                    .fill(barColor)
                    .frame(height: 12)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle()
                                .fill(textColor)
                                .frame(width: 4, height: 4)
                            
                            Rectangle()
                                .fill(textColor)
                                .frame(width: 20, height: 4)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    )
                
                // İçerik alanı
                Rectangle()
                    .fill(contentColor)
                    .frame(height: 40)
                    .overlay(
                        VStack(spacing: 4) {
                            // Metin örneği
                            Rectangle()
                                .fill(textColor)
                                .frame(width: 40, height: 3)
                            
                            // Tahta örneği
                            HStack(spacing: 2) {
                                ForEach(0..<3) { _ in
                                    Rectangle()
                                        .fill(isBejMode ? 
                                              ThemeManager.BejThemeColors.accent.opacity(0.6) : 
                                              themeManager.getBoardColor().opacity(isDarkMode ? 0.7 : 0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            // Buton örneği
                            Rectangle()
                                .fill(isBejMode ? 
                                      ThemeManager.BejThemeColors.accent.opacity(0.8) : 
                                      themeManager.getBoardColor().opacity(isDarkMode ? 0.9 : 0.6))
                                .frame(width: 30, height: 6)
                        }
                        .padding(.vertical, 6)
                    )
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (isBejMode ? ThemeManager.BejThemeColors.accent : themeManager.getBoardColor()) : Color.clear, lineWidth: 2)
            )
            
            // Başlık
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? 
                                 (isBejMode ? ThemeManager.BejThemeColors.accent : themeManager.getBoardColor()) : 
                                 .secondary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? 
                      (isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.1) : themeManager.getBoardColor().opacity(0.1)) : 
                      Color.clear)
        )
    }
    
    // Renk butonları için yardımcı fonksiyon
    private func colorButton(color: Color, name: String, code: String) -> some View {
        Button(action: {
            // Titreşim geri bildirimi
            if enableHapticFeedback {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred(intensity: 0.6)
                SoundManager.shared.playNavigationSound()
        } else {
                SoundManager.shared.playNavigationSoundOnly()
            }
            
            // Animasyon için seçilen rengi kaydet
            selectedColorAnimated = code
            
            // ThemeManager'ı güncelle
            themeManager.sudokuBoardColor = code
            
            // Değişim olduğunu hemen bildir
            themeManager.objectWillChange.send()
            
            // Bildirim gönder
            NotificationCenter.default.post(name: NSNotification.Name("BoardColorChanged"), object: nil)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Renk gösterimi
                    Circle()
                        .fill(themeManager.bejMode ? getBejCompatibleColor(color: color, code: code) : color)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 0)
                        )
                        .scaleEffect(selectedColorAnimated == code ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedColorAnimated)
                    
                    // Seçili renk için işaret
                    if themeManager.sudokuBoardColor == code {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                
                // Gerçek renk adını göster
                Text(name)
                    .font(.system(size: 14, weight: themeManager.sudokuBoardColor == code ? .semibold : .regular))
                    .foregroundColor(themeManager.bejMode ? 
                                     (themeManager.sudokuBoardColor == code ? ThemeManager.BejThemeColors.accent : ThemeManager.BejThemeColors.text) : 
                                     (themeManager.sudokuBoardColor == code ? color : (colorScheme == .dark ? .white : .black)))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.sudokuBoardColor == code ? 
                          (themeManager.bejMode ? ThemeManager.BejThemeColors.accent.opacity(0.15) : color.opacity(0.15)) : 
                          Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Bej mod uyumlu renk döndüren yardımcı fonksiyon
    private func getBejCompatibleColor(color: Color, code: String) -> Color {
        switch code {
        case "red":
            return ThemeManager.BejThemeColors.boardColors.red
        case "pink":
            return ThemeManager.BejThemeColors.boardColors.pink
        case "orange":
            return ThemeManager.BejThemeColors.boardColors.orange
        case "purple":
            return ThemeManager.BejThemeColors.boardColors.purple
        case "green":
            return ThemeManager.BejThemeColors.boardColors.green
        default: // blue
            return ThemeManager.BejThemeColors.boardColors.blue
        }
    }
    
    // Renk kodundan renk adını döndüren yardımcı fonksiyon
    private func getColorNameFromCode(_ colorCode: String) -> String {
        return themeManager.getBoardColorName()
    }
    
    // TextSize değişikliğini işleme fonksiyonu
    private func updateTextSizePreference(_ newValue: TextSizePreference) {
        // Değişikliği AppStorage'a kaydet
        let previousValue = TextSizePreference(rawValue: textSizeString) ?? .medium
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
        
        print("Metin boyutu değiştirildi: \(previousValue.rawValue) -> \(newValue.rawValue)")
    }
}

// Tahta renk seçim butonu (bu yapıyı artık kullanmıyoruz - yukarıdaki colorButton ile değiştirdik)
struct BoardColorButton: View {
    var color: Color
    var name: String
    var isSelected: Bool
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 0)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                
                Text(name)
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.15) : Color.clear)
            )
        }
    }
}

// MARK: - ThemePreferenceKey 
// SwiftUI ortamındaki tema değişikliklerini takip etmek için
struct ThemePreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

// MARK: - ThemeAwareModifier
// Görünümlerin tema değişikliklerine tepki vermesini sağlar
struct ThemeAwareModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var themeID = UUID()
    
    func body(content: Content) -> some View {
        content
            .id(themeID) // Görünümü zorla yenilemek için
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ThemeChanged"))) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Görünümü zorla yenilemek için ID'yi değiştir
                    themeID = UUID()
        }
    }
            .animation(.easeInOut(duration: 0.3), value: themeManager.darkMode)
            .animation(.easeInOut(duration: 0.3), value: themeManager.useSystemAppearance)
    }
}

// Kolay kullanım için extension ekle
extension View {
    func themeAware() -> some View {
        self.modifier(ThemeAwareModifier())
    }
}

struct InfoCard: View {
    var title: String
    var description: String
    var iconName: String
    var color: Color
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    // Bej mod kontrolü için hesaplama
    private var isBejMode: Bool {
        return themeManager.bejMode
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // İkon
            ZStack {
                Circle()
                    .fill(isBejMode ? ThemeManager.BejThemeColors.accent.opacity(0.15) : color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.accent : color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.text : .primary)
                
                Text(description)
                    .scaledFont(size: 14)
                    .foregroundColor(isBejMode ? ThemeManager.BejThemeColors.secondaryText : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isBejMode ? 
                     ThemeManager.BejThemeColors.cardBackground : 
                     (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
    }
}

