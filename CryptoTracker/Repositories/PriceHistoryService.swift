//
//  PriceHistoryService.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 18.03.25.
//

import Foundation

class PriceHistoryService {
    private let firestoreService = CryptoCoinsRepository.shared
    private let effectiveDays = 365
    
    func fetchPriceHistory(for coinId: String, vsCurrency: String) async throws -> [ChartData] {
        // Prüfe zunächst, ob lokale Daten vorhanden und aktuell sind …
        if let localData = loadLocalPriceHistory(for: coinId, vsCurrency: vsCurrency) {
            let localTimestamp = localData.lastUpdated ?? Date.distantPast
            if Date().timeIntervalSince(localTimestamp) <= 65 {
                return localData.data
            }
        }
        
        // Versuche, die Daten aus Firestore zu laden
        if let (firestoreData, firestoreTimestamp) = try? await firestoreService.fetchPriceHistoryData(for: coinId, vsCurrency: vsCurrency) {
            if let firestoreTimestamp = firestoreTimestamp, Date().timeIntervalSince(firestoreTimestamp) <= 65 {
                saveDataToLocalJSON(data: firestoreData, for: coinId, vsCurrency: vsCurrency)
                return firestoreData
            }
        }
        
        // Falls keine aktuellen Daten vorliegen, lade aus der API:
        return try await fetchFromAPI(for: coinId, vsCurrency: vsCurrency)
    }
    
    private func fetchFromAPI(for coinId: String, vsCurrency: String) async throws -> [ChartData] {
        // Hier kannst du vsCurrency hart auf "usd" setzen, um immer USD-Daten zu erhalten.
        let urlString = "https://api.coingecko.com/api/v3/coins/\(coinId)/market_chart?vs_currency=usd&days=\(effectiveDays)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            let chartData = try parsePriceHistoryData(data)
            // Lokale Speicherung (bleibt unverändert – in USD)
            saveDataToLocalJSON(data: chartData, for: coinId, vsCurrency: "usd")
            // Speichern nur bei Änderungen:
            try await firestoreService.savePriceHistoryDataIfChanged(for: coinId, vsCurrency: "usd", data: chartData)
            
            return chartData
        } catch let error as URLError {
            if error.code.rawValue == -1011 {
                throw NSError(domain: "CryptoTracker", code: -1011, userInfo: [NSLocalizedDescriptionKey: "Abfrage-Limit erreicht, bitte versuchen Sie es in einer Minute erneut."])
            }
            throw error
        }
    }
    
    private func parsePriceHistoryData(_ data: Data) throws -> [ChartData] {
        let decoder = JSONDecoder()
        let historyResponse = try decoder.decode(PriceHistoryResponse.self, from: data)
        return historyResponse.prices.compactMap { array in
            guard array.count >= 2 else { return nil }
            return ChartData(date: Date(timeIntervalSince1970: array[0] / 1000), price: array[1])
        }
    }
    
    private func localFileURL(for coinId: String, vsCurrency: String) -> URL {
        let fileName = "\(coinId)_\(vsCurrency)_365.json"
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }
    
    private func saveDataToLocalJSON(data: [ChartData], for coinId: String, vsCurrency: String) {
        let fileURL = localFileURL(for: coinId, vsCurrency: vsCurrency)
        do {
            let localChartData = LocalChartData(data: data, lastUpdated: Date())
            let encodedData = try JSONEncoder().encode(localChartData)
            try encodedData.write(to: fileURL)
            print("✅ Daten wurden lokal gespeichert: \(fileURL.lastPathComponent)")
        } catch {
            print("❌ Fehler beim Speichern der lokalen JSON: \(error)")
        }
    }
    
    private func loadLocalPriceHistory(for coinId: String, vsCurrency: String) -> LocalChartData? {
        let fileURL = localFileURL(for: coinId, vsCurrency: vsCurrency)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LocalChartData.self, from: data)
    }
}
