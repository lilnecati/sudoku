// Önceki kod - sarı uyarılı
guard let user = Auth.auth().currentUser else {
    print("⚠️ Senkronizasyon yapılamıyor: Kullanıcı oturum açmamış")
    return
}

// Yeni kod - uyarısız
guard Auth.auth().currentUser != nil else {
    print("⚠️ Senkronizasyon yapılamıyor: Kullanıcı oturum açmamış")
    return
}# Sudoku Uygulaması Veri Senkronizasyon Senaryoları

Bu belge, Sudoku uygulamasında farklı kullanıcı senaryolarında verilerin nasıl işlendiğini ve cihazlar arası senkronizasyonun nasıl sağlandığını açıklar.

## İçindekiler

1. [Yeni Yükleme Senaryoları](#yeni-yükleme-senaryoları)
2. [Oturum Açma/Kapatma Senaryoları](#oturum-açmakapatma-senaryoları)
3. [Çoklu Cihaz Senaryoları](#çoklu-cihaz-senaryoları)
4. [Veri Senkronizasyon Stratejisi](#veri-senkronizasyon-stratejisi)
5. [Çakışma Çözümü](#çakışma-çözümü)
6. [Offline Kullanım](#offline-kullanım)
7. [Veri Yedekleme ve Kurtarma](#veri-yedekleme-ve-kurtarma)

## Yeni Yükleme Senaryoları

### Senaryo 1: İlk Kez Uygulama Yükleme (Yeni Kullanıcı)
- Kullanıcı uygulamayı ilk kez yüklediğinde konuk (misafir) olarak başlar
- Yerel CoreData veritabanı oluşturulur (boş)
- Temel ayarlar varsayılan değerlerle oluşturulur
- Kullanıcı tercih ederse kaydolabilir

### Senaryo 2: İlk Kez Uygulama Yükleme (Mevcut Hesap)
- Kullanıcı uygulamayı yükleyip hesabına giriş yapar
- Firebase'den kullanıcı verileri çekilir
- CoreData veritabanı Firebase'den gelen verilerle doldurulur:
  - Profil bilgileri
  - Kaydedilmiş oyunlar
  - Başarımlar (achievements)
  - İstatistikler
  - Ayarlar

### Senaryo 3: Uygulamayı Silip Yeniden Yükleme
- Kullanıcı uygulamayı sildiğinde yerel CoreData veritabanı silinir
- Yeniden yüklendiğinde:
  - Kullanıcı giriş yaparsa, verileri Firebase'den geri yüklenir
  - Giriş yapmazsa, yeni bir yerel veritabanı oluşturulur

## Oturum Açma/Kapatma Senaryoları

### Senaryo 4: Oturum Açma
- Kullanıcı oturum açtığında:
  - Firebase'den kullanıcı bilgileri çekilir
  - Yerel veritabanına kaydedilir
  - Var olan yerel konuk verilerinin durumu:
    - İstatistikler ve başarımlar birleştirilir (Firebase verileri öncelikli)
    - Kaydedilmiş oyunlar kullanıcı hesabına taşınır

### Senaryo 5: Oturum Kapatma 
- Kullanıcı oturum kapattığında:
  - Firebase token'ları temizlenir
  - Yerel veri (CoreData) korunur, ancak kullanıcıya özgü veriler (profil bilgileri vb.) kaldırılır
  - Kullanıcı konuk moda geçer
  - İsteğe bağlı olarak tüm verileri temizleme seçeneği sunulabilir

### Senaryo 6: Hesabı Silme
- Kullanıcı hesabını sildiğinde:
  - Firebase'den tüm kullanıcı verileri silinir
  - Yerel veritabanından kullanıcıya ait tüm veriler silinir
  - Konum moda geçiş yapılır

## Çoklu Cihaz Senaryoları

### Senaryo 7: Aynı Hesapla Farklı Cihazlarda Kullanım
- Kullanıcı bir cihazda oturum açtığında:
  - Son senkronizasyon zamanı kontrol edilir
  - Daha yeni Firebase verileri varsa indirilir ve yerel veriler güncellenir
  - Yerel veriler Firebase'den daha yeni ise, Firebase güncellenir
- Oyun ilerleme ve başarımlar cihazlar arasında eşitlenir
- Cihaz özelinde kalan tek veriler: yerel temalar ve cihaza özel ayarlar

### Senaryo 8: Eşzamanlı Çoklu Cihaz Kullanımı
- İki cihazda aynı anda oturum açıldığında:
  - Her cihaz Firebase'e kendi değişikliklerini bildirir
  - Firebase'den yeni değişiklikler alınır
  - Çakışmalar `lastSyncTimestamp` ile çözülür
- Aktif oyunlar cihaza özgü olarak işlenir, tamamlanan oyunlar senkronize edilir
- Oturum mesajı şu şekilde gösterilebilir: "Hesabınız başka bir cihazda aktif"

## Veri Senkronizasyon Stratejisi

### Yerel Veriler (CoreData)
- Her cihazda CoreData ile yerel veri depolama
- Modeller:
  - User
  - SavedGame
  - Achievement
  - HighScore

### Bulut Verileri (Firebase)
- Kullanıcı profilleri
- Kaydedilmiş/tamamlanmış oyunlar
- Başarımlar ve ödüller
- İstatistikler

### Senkronizasyon Tetikleyicileri
- Uygulama başlatma: Otomatik senkronizasyon
- Oyun sonuçlanması: Tamamlanan oyun bilgileri senkronize edilir
- Başarım açma: Yeni başarımlar hemen senkronize edilir
- Periyodik: Arka planda düzenli senkronizasyon (15 dakikada bir)
- Manuel: Kullanıcı tarafından "Şimdi Senkronize Et" ile tetiklenebilir

## Çakışma Çözümü

### Çakışma Durumları
- **Aynı Başarım:** İki cihazda farklı ilerleme durumu
  - Çözüm: Daha yüksek ilerleme değeri kabul edilir
- **Aynı Oyunu Oynama:** İki cihazda aynı oyunun farklı versiyonları
  - Çözüm: Daha yeni timestamp olan versiyon kabul edilir
- **İstatistik Çakışmaları:** Farklı cihazlarda farklı istatistikler
  - Çözüm: Toplama/birleştirme yaklaşımı (örn. tamamlanan oyunların toplamı)

### Timestamp Stratejisi
- Her veri değişikliği `lastSyncTimestamp` ile işaretlenir 
- Senkronizasyon sırasında:
  - Yerel timestamp > Firebase timestamp → Firebase güncellenir
  - Firebase timestamp > Yerel timestamp → Yerel veri güncellenir
  - Eşit timestamp → Değişiklik yok

## Offline Kullanım

### İnternet Bağlantısı Olmadığında
- Kullanıcı tüm özellikleri kullanabilir
- Veriler yerel olarak CoreData'da saklanır
- Değişiklikler bir kuyruğa alınır

### İnternet Bağlantısı Geri Geldiğinde
- Birikmiş değişiklikler Firebase'e gönderilir
- Çakışmalar otomatik olarak çözülür
- Senkronizasyon tamamlandığında kullanıcıya bildirim gösterilebilir

## Veri Yedekleme ve Kurtarma

### Manuel Yedekleme
- Kullanıcı "Verilerimi Yedekle" seçeneğini kullanabilir
- Yedekleme Firebase'de zaman damgalı olarak saklanır
- Ayarlar, kaydedilmiş oyunlar ve başarımlar yedeklenir

### Otomatik Yedekleme
- Haftada bir otomatik yedekleme
- Son 5 yedek saklanır

### Veri Kurtarma
- Kullanıcı istediği yedeği seçebilir
- Eski veriler mevcut verilerin üzerine yazılır
- Seçenek: "Mevcut verilerle birleştir" veya "Tamamen değiştir"

---

## Kullanıcı Deneyimi Örnekleri

### Örnek Senaryo 1: Kullanıcı Telefon Değiştirdiğinde
1. Kullanıcı yeni telefonuna uygulamayı indirir
2. Hesabıyla giriş yapar
3. Tüm verileri otomatik olarak senkronize edilir:
   - Tamamlanmış oyunlar
   - Başarımlar ve puanlar
   - İstatistikler
   - Ayarlar
4. Kaldığı yerden devam edebilir

### Örnek Senaryo 2: Wi-Fi Olmayan Ortamda Oyun
1. Kullanıcı uçak modundayken oynar
2. Başarımlar kazanır, oyunlar tamamlar
3. Veriler yerel olarak kaydedilir
4. İnternet bağlantısı geri geldiğinde tüm veriler otomatik senkronize edilir

### Örnek Senaryo 3: Hem Telefon Hem Tablette Kullanım
1. Kullanıcı sabah telefonunda bir oyun başlatır ve kaydeder
2. Akşam tabletinde oturum açtığında, kaydedilmiş oyun tablette de erişilebilir
3. Tablette oyunu tamamlar
4. Elde ettiği başarımlar ve istatistikler telefonuna da senkronize olur

### Örnek Senaryo 4: Uygulama Kazayla Silinmesi
1. Kullanıcı kazayla uygulamayı siler
2. Yeniden yükleyip hesabına giriş yaptığında tüm verileri geri gelir
3. Hiçbir ilerleme kaybı yaşamaz 

### Örnek Senaryo 5: Uygulama Yükleme, Oynama ve Hesap Silme Döngüsü
1. Kullanıcı uygulamayı ilk kez yükler ve misafir olarak oynar
2. Birkaç oyun oynayıp başarımlar kazanır (veriler yerel CoreData'da saklanır)
3. Hesap oluşturur ve giriş yapar
   - Misafir modunda kazandığı başarımlar ve oyunlar Firebase'e aktarılır
   - Kullanıcı profili oluşturulur
4. Birkaç oyun daha oynar ve yeni başarımlar kazanır
   - Tüm veriler hem yerel CoreData'da hem de Firebase'de güncellenir
5. Kullanıcı hesabını silmeye karar verir:
   - CoreData veritabanındaki kişisel verileri temizlenir
   - Firebase'deki tüm kullanıcı verileri (başarımlar, oyunlar, profil) silinir
   - Kullanıcı otomatik olarak misafir moduna geçer
   - Uygulama ilk yüklenme durumuna döner, sadece temel ayarlar korunur
6. Kullanıcı tekrar hesap açarsa, yeni bir profil olarak başlar
   - Eski verilere artık erişim yoktur (kalıcı olarak silinmiştir)
   - Skorlar, başarımlar ve istatistikler sıfırlanmış durumdadır

### Örnek Senaryo 6: Uygulama Yükleme, Hesap Açma ve Hesaptan Çıkış
1. Kullanıcı uygulamayı ilk kez yükler ve misafir olarak oynar
2. Birkaç oyun oynayıp başarımlar kazanır (veriler yerel CoreData'da saklanır)
3. Hesap oluşturur ve giriş yapar
   - Misafir modunda kazandığı başarımlar ve oyunlar Firebase'e aktarılır
   - Kullanıcı profili oluşturulur 
4. Birkaç oyun daha oynar ve yeni başarımlar kazanır
   - Tüm veriler hem yerel CoreData'da hem de Firebase'de güncellenir
5. Kullanıcı hesabından çıkış yapar:
   - Firebase oturum token'ları silinir
   - Kullanıcıya özel veriler (profil bilgileri, e-posta, vb.) yerel veritabanından temizlenir
   - Oyunlar ve başarımların yerel kopyaları korunur, ancak kullanıcı kimliği ile ilişkileri koparılır
   - Kullanıcı misafir moduna geçer
6. Sonraki kullanım senaryoları:
   - Kullanıcı misafir olarak oynamaya devam edebilir (yeni veriler yerel olarak saklanır)
   - Aynı hesapla tekrar giriş yapabilir (o zaman Firebase'den tüm verileri geri yüklenir)
   - Farklı bir hesapla giriş yapmak isterse:
     * Uygulama öncelikle yerel verilerin senkronize edilmemiş olup olmadığını kontrol eder
     * Senkronize edilmemiş veriler varsa kullanıcıya bildirir ve ne yapmak istediğini sorar
     * Kullanıcı yerel verileri kaybetmemek için önce önceki hesaba giriş yapabilir
     * "Yerel verileri temizle ve yeni hesapla devam et" seçeneği sunulur

7. Hesaba tekrar giriş yaparsa:
   - Firebase'den tüm oyunlar, başarımlar ve istatistikler geri yüklenir
   - Misafir modunda yapılan yeni ilerleme, hesap verileriyle birleştirilir (çakışmalar çözülür)
   - Hesap verileri her iki kaynaktan da (yerel ve Firebase) en güncel olanlar korunarak güncellenir 

## Veri Güvenliği ve Kullanıcı Hesap Koruması

Farklı kullanıcı hesapları arasında verilerin karışmasını önlemek ve kullanıcının ilerlemesini korumak için alınan güvenlik önlemleri:

### Hesap Geçişlerinde Veri Yönetimi

1. **Hesap Değiştirme Güvenlik Protokolü**
   - Kullanıcı hesabından çıkış yapmak istediğinde:
     * Senkronize edilmemiş yerel veriler kontrol edilir
     * Senkronizasyon gerektiren veriler varsa uyarı gösterilir
     * "Çıkış yapmadan önce verileri senkronize et" seçeneği sunulur
   - Farklı bir hesaba giriş yapmak istediğinde:
     * Yerel veritabanı temizleme onayı alınır
     * Kaybolabilecek veriler hakkında açık uyarı gösterilir

2. **Yerel Veri İzolasyonu**
   - Her kullanıcı hesabı için ayrı yerel depolama alanı kullanılır
   - Kullanıcı ID'sine göre veri bölümleme yapılır
   - Bir kullanıcının verileri diğerinin alanına sızmaz

3. **Otomatik Veri Etiketleme**
   - Tüm veriler oluşturulduğu ve değiştirildiği kullanıcı ID'si ile etiketlenir
   - Kullanıcı hesap değiştirdiğinde, etiket kontrolü yapılır
   - Eşleşmeyen etiketli veriler yüklenmez veya birleştirilmez

### Hesap Güvenliği

1. **Kullanıcı Kimliği Doğrulama**
   - Her oturum açma işleminde Firebase Authentication üzerinden tam doğrulama yapılır
   - Yerel depolanan veriler kullanıcı kimliği ile şifrelenir
   - Oturumun başka bir cihazda açılması durumunda bildirim gönderilir
   
2. **Çıkış Yapma ve Hesap Değiştirme**
   - Hesaptan çıkış yapılırken kullanıcıya üç seçenek sunulur:
     * "Çıkış yap ve verilerimi bu cihazda tut" (varsayılan)
     * "Çıkış yap ve verilerimi bu cihazdan tamamen temizle"
     * "İptal"
   - Başka bir hesaba giriş yapılacaksa, öncelikle mevcut verilerin temizlenmesi zorunlu tutulur

3. **Hesap Kurtarma Mekanizması**
   - Senkronize edilmemiş veriler olması durumunda otomatik yedekleme yapılır
   - Kullanıcı farkında olmadan hesap değiştirirse 24 saat içinde eski verilerine erişebilir
   - Acil durumlar için "Son Oturumu Kurtar" seçeneği sunulur

Bu önlemler, kullanıcıların yanlışlıkla başka hesaplara giriş yapmalarından ve verilerinin karışmasından kaynaklı sorunları önlemeye yardımcı olur. 