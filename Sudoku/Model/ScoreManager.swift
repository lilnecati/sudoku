import Foundation
import CoreData

class ScoreManager {
    static let shared = ScoreManager()
    
    private let context: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }
    
    // MARK: - Puan Hesaplama
    
    func calculateScore(difficulty: SudokuBoard.Difficulty,
                       timeElapsed: TimeInterval,
                       errorCount: Int,
                       hintCount: Int) -> (baseScore: Int, timeBonus: Int, totalScore: Int) {
        
        // Zorluk seviyesine göre baz puan
        let baseScore: Int
        switch difficulty {
        case .easy:
            baseScore = 1000
        case .medium:
            baseScore = 2000
        case .hard:
            baseScore = 3000
        case .expert:
            baseScore = 4000
        }
        
        // Süre bonusu hesaplama
        let timeBonus: Int
        let minutes = timeElapsed / 60
        switch difficulty {
        case .easy:
            timeBonus = minutes <= 5 ? 500 : minutes <= 10 ? 300 : minutes <= 15 ? 100 : 0
        case .medium:
            timeBonus = minutes <= 10 ? 1000 : minutes <= 15 ? 500 : minutes <= 20 ? 200 : 0
        case .hard:
            timeBonus = minutes <= 15 ? 1500 : minutes <= 20 ? 1000 : minutes <= 25 ? 500 : 0
        case .expert:
            timeBonus = minutes <= 20 ? 2000 : minutes <= 25 ? 1500 : minutes <= 30 ? 1000 : 0
        }
        
        // Hata ve ipucu kesintileri
        let errorPenalty = errorCount * 200
        let hintPenalty = hintCount * 300
        
        // Toplam skor hesaplama
        let totalScore = max(0, baseScore + timeBonus - errorPenalty - hintPenalty)
        
        return (baseScore, timeBonus, totalScore)
    }
    
    // MARK: - Veri Kaydetme
    
    func saveScore(difficulty: SudokuBoard.Difficulty,
                  timeElapsed: TimeInterval,
                  errorCount: Int,
                  hintCount: Int,
                  moveCount: Int = 0) {
        
        logInfo("Skor kaydediliyor - Zorluk: \(difficulty.rawValue), Süre: \(timeElapsed), Hatalar: \(errorCount), İpuçları: \(hintCount)")
        
        // Skor hesaplaması yap ve sonuçları kullan
        let scoreResults = calculateScore(
            difficulty: difficulty,
            timeElapsed: timeElapsed,
            errorCount: errorCount,
            hintCount: hintCount
        )
        
        // HighScore entity'sini kullan
        let entity = NSEntityDescription.entity(forEntityName: "HighScore", in: context)!
        let score = NSManagedObject(entity: entity, insertInto: context)
        
        // Değerleri ayarla
        let scoreId = UUID()
        score.setValue(scoreId, forKey: "id")
        score.setValue(difficulty.rawValue, forKey: "difficulty")
        score.setValue(timeElapsed, forKey: "elapsedTime")
        score.setValue(Date(), forKey: "date")
        score.setValue("Oyuncu", forKey: "playerName")
        
        // Yeni alanları da kaydet
        score.setValue(scoreResults.baseScore, forKey: "baseScore")
        score.setValue(scoreResults.timeBonus, forKey: "timeBonus")
        score.setValue(errorCount, forKey: "errorCount")
        score.setValue(hintCount, forKey: "hintCount")
        score.setValue(scoreResults.totalScore, forKey: "totalScore")
        score.setValue(moveCount, forKey: "moveCount")
        
        do {
            try context.save()
            logSuccess("Skor başarıyla kaydedildi: ID: \(scoreId), Toplam Puan: \(scoreResults.totalScore)")
            
            // Skoru doğrudan Firebase'e de kaydet
            PersistenceController.shared.saveHighScoreToFirestore(
                scoreID: scoreId.uuidString,
                difficulty: difficulty.rawValue,
                elapsedTime: timeElapsed,
                errorCount: errorCount,
                hintCount: hintCount,
                score: scoreResults.totalScore,
                playerName: "Oyuncu"
            )
            
            // Kaydedilen skoru kontrol et
            validateScoreSaved(scoreId: scoreId)
        } catch {
            logError("Skor kaydedilemedi: \(error.localizedDescription)")
        }
    }
    
    // Skorun gerçekten kaydedilip kaydedilmediğini kontrol et
    private func validateScoreSaved(scoreId: UUID) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "id == %@", scoreId as CVarArg)
        
        do {
            let scores = try context.fetch(request)
            if let score = scores.first {
                if let id = score.value(forKey: "id") as? UUID {
                    logDebug("Skor doğrulandı: \(id.uuidString)")
                } else {
                    logDebug("Skor doğrulandı: ID yok")
                }
                logDebug("Toplam Skor: \(score.value(forKey: "totalScore") as? Int ?? 0)")
                logDebug("Zorluk: \(score.value(forKey: "difficulty") as? String ?? "Zorluk yok")")
            } else {
                logError("HATA: Skor kaydedildi ama veritabanında bulunamadı!")
            }
        } catch {
            logError("Skor kontrolü sırasında hata: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Veri Sorgulama
    
    func getBestScore(for difficulty: SudokuBoard.Difficulty) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        
        // İlk önce totalScore'a göre sırala, sonra elapsedTime'a göre
        request.sortDescriptors = [
            NSSortDescriptor(key: "totalScore", ascending: false),
            NSSortDescriptor(key: "elapsedTime", ascending: true)
        ]
        request.fetchLimit = 1
        
        do {
            let scores = try context.fetch(request)
            if let bestScore = scores.first {
                // totalScore varsa kullan, yoksa elapsedTime ile hesapla
                if let totalScore = bestScore.value(forKey: "totalScore") as? Int, totalScore > 0 {
                    return totalScore
                } else if let time = bestScore.value(forKey: "elapsedTime") as? Double {
                    // Eski hesaplama yöntemi
                    return Int(10000 / (time + 1))
                }
            }
            return 0
        } catch {
            logWarning("En yüksek skor alınamadı: \(error.localizedDescription)")
            return 0
        }
    }
    
    func getAverageScore(for difficulty: SudokuBoard.Difficulty) -> Double {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        
        do {
            let scores = try context.fetch(request)
            if scores.isEmpty { return 0 }
            
            var totalScore = 0
            var scoreCount = 0
            
            for score in scores {
                // totalScore varsa kullan, yoksa elapsedTime ile hesapla
                if let totalScoreValue = score.value(forKey: "totalScore") as? Int, totalScoreValue > 0 {
                    totalScore += totalScoreValue
                    scoreCount += 1
                } else if let time = score.value(forKey: "elapsedTime") as? Double {
                    // Eski hesaplama yöntemi
                    totalScore += Int(10000 / (time + 1))
                    scoreCount += 1
                }
            }
            
            return scoreCount > 0 ? Double(totalScore) / Double(scoreCount) : 0
        } catch {
            logWarning("Ortalama skor hesaplanamadı: \(error.localizedDescription)")
            return 0
        }
    }
}