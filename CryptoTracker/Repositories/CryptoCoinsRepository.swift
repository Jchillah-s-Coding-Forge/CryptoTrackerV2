//
//  FirestoreService.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 18.03.25.
//

import Foundation
import FirebaseFirestore

class CryptoCoinsRepository {
    static let shared = CryptoCoinsRepository()
    private let db = Firestore.firestore()
    private let effectiveDays = 7 // Anzahl der Tage für den Preisverlauf
    
    private init() {}
    
    // MARK: - Coins speichern und abrufen
    func saveCoin(_ coin: Crypto) async throws {
        try db.collection("coins").document(coin.id).setData(from: coin)
    }
    
    func fetchCoins() async throws -> [Crypto] {
        let snapshot = try await db.collection("coins")
            .order(by: "marketCapRank")
            .getDocuments()
        let coins = snapshot.documents.compactMap { try? $0.data(as: Crypto.self) }
        print("🔍 Firestore enthält \(coins.count) Coins.")
        return coins
    }
    
    // MARK: - Zeitstempel verwalten
    func getLastUpdatedTime() async throws -> Date? {
        let doc = try await db.collection("meta").document("lastUpdated").getDocument()
        if let timestamp = doc.data()?["timestamp"] as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }
    
    // Lädt das zuletzt aktualisierte Datum aus Firestore und gibt es im deutschen Format zurück
    func getLastUpdatedTimeFormatted() async throws -> String? {
        let doc = try await db.collection("meta").document("lastUpdated").getDocument()
        if let timestamp = doc.data()?["timestamp"] as? Timestamp {
            return DateFormatterUtil.formatDateToGermanStyle(timestamp.dateValue())
        }
        return nil
    }
    
    func setLastUpdatedTime() async throws {
        let ref = db.collection("meta").document("lastUpdated")
        try await ref.setData(["timestamp": Timestamp(date: Date())])
    }
    
    // MARK: - Alle Coins speichern und abrufen
    func saveAllCoins(_ coins: [Crypto]) async throws {
        let coinsData = CoinsData(coins: coins, timestamp: Date())
        try db.collection("crypto").document("coins").setData(from: coinsData)
        print("✅ Alle Coins wurden in Firestore gespeichert.")
    }
    
    func fetchAllCoins() async throws -> (coins: [Crypto], timestamp: Date) {
        let doc = try await db.collection("crypto").document("coins").getDocument()
        
        // Falls das Dokument nicht existiert oder keine Daten enthält:
        guard let _ = doc.data() else {
            print("🔍 Firestore Coins-Dokument existiert nicht.")
            return ([], Date.distantPast)
        }
        
        let coinsData = try doc.data(as: CoinsData.self)
        print("🔍 Firestore Coins-Dokument enthält \(coinsData.coins.count) Coins.")
        return (coinsData.coins, coinsData.timestamp)
    }
    
    // MARK: - Preisverlauf abrufen & speichern
    func fetchFromAPI(for coinId: String, vsCurrency: String) async throws -> [ChartData] {
        let urlString = "https://api.coingecko.com/api/v3/coins/\(coinId)/market_chart?vs_currency=\(vsCurrency)&days=\(effectiveDays)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let chartData = try parsePriceHistoryData(data)
            // Lokale Speicherung beibehalten:
            saveDataToLocalJSON(data: chartData, for: coinId, vsCurrency: vsCurrency)
            // Hier wird nur gespeichert, wenn sich die Daten geändert haben:
            try await savePriceHistoryDataIfChanged(for: coinId, vsCurrency: vsCurrency, data: chartData)
            
            return chartData
        } catch let error as URLError {
            // NSURLErrorDomain error -1011 entspricht .badServerResponse
            if error.code == .badServerResponse {
                throw NSError(domain: "CryptoTracker", code: error.code.rawValue, userInfo: [NSLocalizedDescriptionKey: "Abfrage-Limit erreicht, bitte versuchen Sie es in einer Minute erneut."])
            }
            throw error
        }
    }
    
    // Alte Version beibehalten (falls benötigt)
    func savePriceHistoryData(for coinId: String, vsCurrency: String, data: [ChartData], newTimestamp: Date) async throws {
        let ref = db.collection("chartData").document("\(coinId)_\(vsCurrency)")
        let encodedData = try JSONEncoder().encode(data)
        let jsonString = String(data: encodedData, encoding: .utf8) ?? "[]"
        try await ref.setData(["data": jsonString, "timestamp": Timestamp(date: newTimestamp)])
    }
    
    func fetchPriceHistoryData(for coinId: String, vsCurrency: String) async throws -> ([ChartData], Date?) {
        let ref = db.collection("chartData").document("\(coinId)_\(vsCurrency)")
        let doc = try await ref.getDocument()
        guard let data = doc.data(),
              let timestamp = data["timestamp"] as? Timestamp,
              let jsonString = data["data"] as? String else {
            throw NSError(domain: "Firestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keine Chart-Daten gefunden"])
        }
        let jsonData = Data(jsonString.utf8)
        let priceHistory = try JSONDecoder().decode([ChartData].self, from: jsonData)
        return (priceHistory, timestamp.dateValue())
    }
    
    // MARK: - Favoriten verwalten
    func addFavoriteCoin(userId: String, coinId: String) async throws {
        let ref = db.collection("users").document(userId).collection("favorites").document(coinId)
        try await ref.setData(["coinId": coinId])
    }
    
    func removeFavoriteCoin(userId: String, coinId: String) async throws {
        let ref = db.collection("users").document(userId).collection("favorites").document(coinId)
        try await ref.delete()
    }
    
    func getFavoriteCoins(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users").document(userId).collection("favorites").getDocuments()
        return snapshot.documents.compactMap { $0.data()["coinId"] as? String }
    }
    
    // MARK: - Hilfsmethoden
    private func parsePriceHistoryData(_ data: Data) throws -> [ChartData] {
        let decoder = JSONDecoder()
        // Versuche, den JSON-Response in PriceHistoryResponse zu decodieren
        let historyResponse = try decoder.decode(PriceHistoryResponse.self, from: data)
        
        // Erzeuge ChartData-Objekte aus den "prices"
        let chartData = historyResponse.prices.compactMap { array -> ChartData? in
            guard array.count >= 2 else { return nil }
            // API liefert den Zeitstempel in Millisekunden, daher teilen wir durch 1000
            let timestamp = array[0] / 1000
            let price = array[1]
            return ChartData(date: Date(timeIntervalSince1970: timestamp), price: price)
        }
        
        return chartData
    }
    
    private func saveDataToLocalJSON(data: [ChartData], for coinId: String, vsCurrency: String) {
        let filename = "\(coinId)_\(vsCurrency).json"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: url!)
            print("✅ Daten wurden lokal gespeichert: \(filename)")
        } catch {
            print("❌ Fehler beim Speichern der Daten: \(error)")
        }
    }
    
    // MARK: - Funktionen zur bedingten Aktualisierung
    func saveCoinIfChanged(_ coin: Crypto) async throws {
        let docRef = db.collection("coins").document(coin.id)
        let existingDoc = try? await docRef.getDocument()
        
        if let existingData = try? existingDoc?.data(as: Crypto.self), existingData == coin {
            print("🔹 Keine Änderungen für Coin \(coin.id), kein Update nötig.")
            return
        }
        
        let coinData: [String: Any] = [
            "updateTimestamp": Timestamp(date: Date()),
            "id": coin.id,
            "symbol": coin.symbol,
            "name": coin.name,
            "image": coin.image,
            "current_price": coin.currentPrice,
            "market_cap": coin.marketCap,
            "market_cap_rank": coin.marketCapRank,
            "total_volume": coin.volume,
            "high_24h": coin.high24h,
            "low_24h": coin.low24h,
            "price_change_24h": coin.priceChange24h,
            "price_change_percentage_24h": coin.priceChangePercentage24h,
            "last_updated": coin.lastUpdated
        ]
        
        try await docRef.setData(coinData)
        print("✅ Coin \(coin.id) wurde aktualisiert.")
    }
    
    func saveAllCoinsIfChanged(_ coins: [Crypto]) async throws {
        for coin in coins {
            try await saveCoinIfChanged(coin)
        }
        print("✅ Aktualisierte Coins wurden gespeichert.")
    }
    
    func savePriceHistoryDataIfChanged(for coinId: String, vsCurrency: String, data: [ChartData]) async throws {
        let ref = db.collection("chartData").document("\(coinId)_\(vsCurrency)")
        
        let existingDoc = try? await ref.getDocument()
        if let existingData = existingDoc?.data(),
           let jsonString = existingData["data"] as? String,
           let jsonData = jsonString.data(using: .utf8),
           let oldData = try? JSONDecoder().decode([ChartData].self, from: jsonData),
           oldData == data {
            print("🔹 Keine Änderungen für \(coinId), kein Update nötig.")
            return
        }
        
        let encodedData = try JSONEncoder().encode(data)
        let newJsonString = String(data: encodedData, encoding: .utf8) ?? "[]"
        let dataToSave: [String: Any] = [
            "timestamp": Timestamp(date: Date()),
            "data": newJsonString
        ]
        try await ref.setData(dataToSave)
        print("✅ Preisverlauf für \(coinId) wurde aktualisiert.")
    }
    
    // MARK: - Initialisierung des Coins-Dokuments
    func initializeCoinsDataIfNeeded() async throws {
        let doc = try await db.collection("crypto").document("coins").getDocument()
        // Falls das Dokument nicht existiert oder keine Daten enthält:
        guard let _ = doc.data() else {
            let coinsData = CoinsData(coins: [], timestamp: Date())
            try db.collection("crypto").document("coins").setData(from: coinsData)
            print("🔹 Leeres Coins-Dokument wurde initialisiert.")
            return
        }
    }
}
