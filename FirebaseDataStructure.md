# Firebase Veri Yapısı - Yeni Tasarım

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                 FIREBASE FIRESTORE                                               │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  users          │  │ userAchievements│  │  userGames      │  │  userStats      │  │  userPreferences│
└─────┬───────────┘  └─────┬───────────┘  └─────┬───────────┘  └─────┬───────────┘  └─────┬───────────┘
      │                    │                    │                    │                    │
      ▼                    ▼                    ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ [UID]           │  │ [UID]           │  │ [UID]           │  │ [UID]           │  │ [UID]           │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ username        │  │ totalPoints     │  │ totalGames      │  │ totalPlayTime   │  │ theme           │
│ email           │  │ lastSyncDate    │  │ activeSessions  │  │ gamesCompleted  │  │ notifications   │
│ name            │  │ categories      │  │ lastPlayed      │  │ winRate         │  │ soundEnabled    │
│ registrationDate│  │                 │  │                 │  │ averageTime     │  │ hapticEnabled   │
│ isLoggedIn      │  │                 │  │                 │  │ totalScore      │  │ darkMode        │
│ profileImageURL │  │                 │  │                 │  │ totalErrors     │  │ language        │
│ lastActive      │  │                 │  │                 │  │ totalHints      │  │ difficultyPref  │
└─────────────────┘  └─────┬───────────┘  └─────┬───────────┘  └─────────────────┘  └─────────────────┘
                           │                     │                                   
                           ▼                     ▼                                   
                     ┌─────────────────┐   ┌─────────────────┐                      
                     │  categories     │   │  savedGames     │                      
                     │ (alt koleksiyon)│   │ (alt koleksiyon)│                      
                     └─────┬───────────┘   └─────┬───────────┘                      
                           │                     │                                   
                           ▼                     ▼                                   
                     ┌─────────────────┐   ┌─────────────────┐                      
                     │ [categoryName]  │   │ [gameID]        │                      
                     │ (easy, medium,  │   ├─────────────────┤                      
                     │  hard, expert,  │   │ gameData        │                      
                     │  streak, time,  │   │ difficulty      │                      
                     │  special, vb.)  │   │ createdAt       │                      
                     ├─────────────────┤   │ lastUpdated     │                      
                     │ achievements    │   │ elapsedTime     │                      
                     │ lastUpdated     │   │ moveCount       │                      
                     │ count           │   │ errorCount      │                      
                     │ originalCategory│   │ hintCount       │                      
                     └─────────────────┘   │ completion%     │                      
                                           │ deviceID        │                      
                                           └─────────────────┘                      
                                                                                    
                                           ┌─────────────────┐                      
                                           │  completedGames │                      
                                           │ (alt koleksiyon)│                      
                                           └─────┬───────────┘                      
                                                 │                                   
                                                 ▼                                   
                                           ┌─────────────────┐                      
                                           │ [gameID]        │                      
                                           ├─────────────────┤                      
                                           │ difficulty      │                      
                                           │ completedAt     │                      
                                           │ elapsedTime     │                      
                                           │ moveCount       │                      
                                           │ errorCount      │                      
                                           │ hintCount       │                      
                                           │ score           │                      
                                           └─────────────────┘                      
                                                                                    
                                           ┌─────────────────┐                      
                                           │  highScores     │                      
                                           │ (alt koleksiyon)│                      
                                           └─────┬───────────┘                      
                                                 │                                   
                                                 ▼                                   
                                           ┌─────────────────┐                      
                                           │ [difficulty]    │                      
                                           ├─────────────────┤                      
                                           │ bestScore       │                      
                                           │ bestTime        │                      
                                           │ date            │                      
                                           │ gameID          │                      
                                           └─────────────────┘                      

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  userActivity   │  │  notifications  │  │  friends        │
└─────┬───────────┘  └─────┬───────────┘  └─────┬───────────┘
      │                    │                    │
      ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ [UID]           │  │ [UID]           │  │ [UID]           │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ lastLogin       │  │ unreadCount     │  │ friendsList     │
│ deviceHistory   │  │                 │  │ pendingRequests │
│ loginHistory    │  │                 │  │ blockedUsers    │
└─────┬───────────┘  └─────┬───────────┘  └─────────────────┘
      │                    │
      ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│  events         │  │  messages       │
│  (alt koleksiyon)│  │  (alt koleksiyon)│
└─────┬───────────┘  └─────┬───────────┘
      │                    │
      ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│ [eventID]       │  │ [messageID]     │
├─────────────────┤  ├─────────────────┤
│ eventType       │  │ title           │
│ timestamp       │  │ content         │
│ details         │  │ timestamp       │
│ deviceID        │  │ isRead          │
└─────────────────┘  │ type            │
                     └─────────────────┘
```

## Veri İlişkileri - Yeni Tasarım

1. **Kullanıcı Merkezli Yapı**:
   - Her kullanıcı için `users` koleksiyonunda bir belge bulunur (belge ID = kullanıcı UID'si).
   - Kullanıcıya ait tüm veriler, kullanıcı UID'si ile ilişkilendirilmiş koleksiyonlarda saklanır.

2. **Başarımlar**:
   - `userAchievements` koleksiyonunda her kullanıcı için bir belge bulunur (belge ID = kullanıcı UID'si).
   - Her kullanıcının başarımları, alt koleksiyon olarak kategorilere ayrılmış şekilde saklanır.

3. **Oyunlar**:
   - `userGames` koleksiyonunda her kullanıcı için bir belge bulunur (belge ID = kullanıcı UID'si).
   - Kullanıcının kayıtlı oyunları `savedGames` alt koleksiyonunda saklanır.
   - Tamamlanan oyunlar `completedGames` alt koleksiyonunda saklanır.
   - Yüksek skorlar `highScores` alt koleksiyonunda zorluk seviyesine göre saklanır.

4. **İstatistikler ve Tercihler**:
   - `userStats` ve `userPreferences` koleksiyonlarında her kullanıcı için bir belge bulunur.

5. **Aktivite ve Bildirimler**:
   - `userActivity` ve `notifications` koleksiyonlarında her kullanıcı için bir belge bulunur.
   - Aktivite olayları ve bildirimler alt koleksiyonlarda saklanır.

6. **Arkadaşlık İlişkileri**:
   - `friends` koleksiyonunda her kullanıcı için bir belge bulunur.
   - Arkadaş listesi, bekleyen istekler ve engellenen kullanıcılar bu belgede saklanır.

## Avantajlar

1. **Kolay Erişim**:
   - Bir kullanıcının tüm verilerine doğrudan UID üzerinden erişilebilir.
   - Örneğin: `db.collection("userGames").document(uid)` ile kullanıcının oyun özetine erişim.
   - Detaylar için: `db.collection("userGames").document(uid).collection("savedGames")` ile tüm kayıtlı oyunlara erişim.

2. **Verimli Sorgular**:
   - Kullanıcı bazlı sorgular daha hızlı ve verimli olur.
   - Bir kullanıcının tüm verilerini tek seferde almak yerine, ihtiyaç duyulan alt koleksiyonlara erişim sağlanabilir.

3. **Güvenlik Kuralları**:
   - Firestore güvenlik kuralları daha basit ve etkili bir şekilde uygulanabilir.
   - Örnek: `match /userGames/{userId} { allow read, write: if request.auth.uid == userId; }`

4. **Ölçeklenebilirlik**:
   - Kullanıcı sayısı arttıkça, her kullanıcının verileri kendi belgelerinde izole edilmiş olur.
   - Bu, büyük koleksiyonlarda performans sorunlarını önler.

## Geçiş Stratejisi

1. **Yeni Kullanıcılar**:
   - Yeni kullanıcılar için doğrudan yeni yapı kullanılabilir.

2. **Mevcut Kullanıcılar**:
   - Mevcut kullanıcıların verileri, arka planda kademeli olarak yeni yapıya taşınabilir.
   - Geçiş sırasında hem eski hem de yeni yapı desteklenebilir.

3. **Veri Migrasyonu**:
   - Bir Cloud Function kullanılarak, eski yapıdaki veriler yeni yapıya otomatik olarak taşınabilir.
