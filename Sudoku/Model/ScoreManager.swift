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
                  hintCount: Int) {
        
        // Skor hesaplamasını kullanmıyoruz çünkü HighScore entity'si farklı alanlar içeriyor
        _ = calculateScore(
            difficulty: difficulty,
            timeElapsed: timeElapsed,
            errorCount: errorCount,
            hintCount: hintCount
        )
        
        // HighScore entity'sini kullan
        let entity = NSEntityDescription.entity(forEntityName: "HighScore", in: context)!
        let score = NSManagedObject(entity: entity, insertInto: context)
        
        // Değerleri ayarla
        score.setValue(difficulty.rawValue, forKey: "difficulty")
        score.setValue(timeElapsed, forKey: "elapsedTime")
        score.setValue(Date(), forKey: "date")
        score.setValue("Oyuncu", forKey: "playerName")
        
        do {
            try context.save()
        } catch {
            print("Skor kaydedilemedi: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Veri Sorgulama
    
    func getBestScore(for difficulty: SudokuBoard.Difficulty) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "elapsedTime", ascending: true)]
        request.fetchLimit = 1
        
        do {
            let scores = try context.fetch(request)
            // HighScore entity'sinde elapsedTime kullanılıyor, bunu puana çeviriyoruz
            if let bestScore = scores.first, let time = bestScore.value(forKey: "elapsedTime") as? Double {
                // Basit bir puan hesaplama - daha düşük süre daha yüksek puan
                return Int(10000 / (time + 1))
            }
            return 0
        } catch {
            print("En yüksek skor alınamadı: \(error.localizedDescription)")
            return 0
        }
    }
    
    func getAverageScore(for difficulty: SudokuBoard.Difficulty) -> Double {
        let request = NSFetchRequest<NSManagedObject>(entityName: "HighScore")
        request.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        
        do {
            let scores = try context.fetch(request)
            if scores.isEmpty { return 0 }
            
            // HighScore entity'sinde elapsedTime kullanılıyor, bunu puana çeviriyoruz
            let totalTime = scores.reduce(0.0) { $0 + ((($1.value(forKey: "elapsedTime") as? Double) ?? 0)) }
            // Daha düşük süreyi daha iyi olduğu için, ortalama süreyi tersine çeviriyoruz
            return scores.isEmpty ? 0 : 10000 / (totalTime / Double(scores.count) + 1)
        } catch {
            print("Ortalama skor hesaplanamadı: \(error.localizedDescription)")
            return 0
        }
    }
}