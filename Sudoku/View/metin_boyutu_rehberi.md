# Sudoku Uygulaması Metin Boyutu Ayarları Rehberi

Bu dokümanda Sudoku uygulamasındaki metin boyutu ayarları butonlarının nasıl aktifleştirildiği anlatılmaktadır.

## Metin Boyutu Ayar Butonlarının Aktifleştirilmesi

Ayarlar ekranında metin boyutu seçeneklerini aktifleştirmek için aşağıdaki adımlar izlenmiştir:

### 1. TextSizePreference Enum'u

SudokuApp.swift dosyasında, metin boyutu tercihlerini yönetmek için bir enum tanımlanmıştır:

```swift
enum TextSizePreference: String, CaseIterable {
    case small = "Küçük"
    case medium = "Orta"
    case large = "Büyük"
    
    var displayName: String {
        return self.rawValue
    }
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.85  // Daha küçük boyut
        case .medium: return 1.0  // Normal boyut
        case .large: return 1.2   // Daha büyük boyut
        }
    }
}
```

### 2. TextSizeExtension.swift

DynamicTypeSize ile entegrasyonu sağlamak için bir uzantı eklenmiştir:

```swift
import SwiftUI

extension TextSizePreference {
    func toDynamicTypeSize() -> DynamicTypeSize {
        switch self {
        case .small:
            return .xSmall
        case .medium:
            return .large
        case .large:
            return .xLarge
        }
    }
}
```

### 3. SettingsView.swift'te Butonların Eklenmesi

Ayarlar sayfasında metin boyutu seçenekleri için aşağıdaki kod eklenmiştir:

```swift
// Metin boyutu ayarı
Section(header: Text("Metin Boyutu").foregroundColor(.secondary)) {
    HStack {
        Text("Metin Boyutu")
        Spacer()
        Text(textSizePreference.displayName)
            .foregroundColor(.secondary)
    }
    .contentShape(Rectangle())
    .onTapGesture {
        showTextSizePicker = true
    }
    
    // Metin boyutu seçim ekranı
    if showTextSizePicker {
        Picker(selection: $textSizePreference, label: Text("Metin Boyutu")) {
            ForEach(TextSizePreference.allCases, id: \.self) { size in
                Text(size.displayName).tag(size)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.vertical, 8)
        .onChange(of: textSizePreference) { oldValue, newValue in
            updateTextSizePreference(newValue)
        }
    }
}
```

### 4. TextSize Değişikliğini İşleme Fonksiyonu

SettingsView içinde metin boyutu değişikliklerini işlemek için bir fonksiyon tanımlanmıştır:

```swift
private func updateTextSizePreference(_ newValue: TextSizePreference) {
    // Değişikliği AppStorage'a kaydet
    let previousValue = textSizePreference
    // String değeri güncelle
    textSizeString = newValue.rawValue
    textSizePreference = newValue
    
    // Değişikliği bildir
    NotificationCenter.default.post(name: Notification.Name("TextSizeChanged"), object: nil)
    
    // Bildirim sesi çal
    SoundManager.shared.playNavigationSound()
    
    print("📱 Metin boyutu değiştirildi: \(previousValue.rawValue) -> \(newValue.rawValue)")
}
```

### 5. SudokuApp.swift'te Değişiklikleri Dinleme

Ana uygulama dosyasında text size değişikliği dinleyicisi eklenmiştir:

```swift
.onAppear {
    // Metin boyutu değişim bildirimini dinle
    NotificationCenter.default.addObserver(forName: Notification.Name("TextSizeChanged"), object: nil, queue: .main) { notification in
        print("📱 Text size changed to: \(self.textSizePreference.rawValue)")
        
        // UI'ı yenile
        self.viewUpdateTrigger.toggle()
        
        // Force UI update
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForceUIUpdate"), object: nil)
        }
    }
}
```

### 6. DynamicTypeSize Uygulanması

Uygulamanın ContentView'ında dinamik metin boyutu uygulanmıştır:

```swift
ContentView()
    .environment(\.locale, Locale(identifier: localizationManager.currentLanguage.code))
    .preferredColorScheme(themeManager.colorScheme)
    .environment(\.dynamicTypeSize, textSizePreference.toDynamicTypeSize())
```

## Kullanıcı Deneyimi

1. Kullanıcı Ayarlar sayfasına gider
2. "Metin Boyutu" seçeneğine dokunur
3. Açılan segmentli seçiciyle "Küçük", "Orta" veya "Büyük" boyuttan birini seçer
4. Seçim yapıldığında:
   - Ayar AppStorage'a kaydedilir
   - NotificationCenter üzerinden TextSizeChanged bildirimi gönderilir
   - Uygulama arayüzü yeni metin boyutuna göre yenilenir
   - Etkileşim ses efekti çalınır

## Önemli Not

Oyunu oluşturan Sudoku tahtası, hücreler ve sayı tuşları, önceki rehberde açıklandığı gibi, metin boyutu değişikliklerinden etkilenmemesi için sabit metin boyutu ile yapılandırılmıştır. Bu sayede kullanıcı arayüz metin boyutunu değiştirirken oyun oynama deneyimi bozulmaz.

