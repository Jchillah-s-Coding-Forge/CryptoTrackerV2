//
//  CryptoService.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 12.03.25.
//

import Foundation

class CryptoService {
    private let coinDataURLBase = "https://api.coingecko.com/api/v3/coins/markets?vs_currency="
    private let exchangeRatesURL = "https://api.coingecko.com/api/v3/exchange_rates"
    
    private var exchangeRates: [String: Double] = [:]
    
    func fetchCryptoDataFromAPI(for currency: String) async throws -> [Crypto] {
        let urlString = "\(coinDataURLBase)\(currency)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode([Crypto].self, from: data)
        } catch {
            if let urlError = error as? URLError, urlError.code == .badServerResponse {
                throw NSError(
                    domain: "CryptoTracker",
                    code: urlError.code.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Abfrage-Limit erreicht, bitte versuchen Sie es in einer Minute erneut."]
                )
            }
            throw error
        }
    }
    
    func fetchExchangeRatesFromAPI() async throws {
        guard let url = URL(string: exchangeRatesURL) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
        exchangeRates = ratesResponse.rates.mapValues { $0.value }
    }
    
    func getConversionRate(for currency: String) -> Double {
        return exchangeRates[currency.lowercased()] ?? 1.0 
    }
    
    
    func fetchPriceHistoryFromAPI(for coinId: String, vsCurrency: String) async throws -> [ChartData] {
        let urlString = "https://api.coingecko.com/api/v3/coins/\(coinId)/market_chart?vs_currency=\(vsCurrency)&days=365"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            saveDataToLocalJSON(data: data, for: coinId, vsCurrency: vsCurrency)
            return try parsePriceHistoryData(data)
        } catch {
            if let localData = loadLocalJSON(for: coinId, vsCurrency: vsCurrency) {
                do {
                    return try parsePriceHistoryData(localData)
                } catch {
                    print("Fehler beim Parsen der lokalen JSON-Daten: \(error)")
                }
            }
            print("Kein lokaler Cache verfügbar. Rückgabe eines leeren Arrays. Fehler: \(error)")
            return []
        }
    }
    
    private func parsePriceHistoryData(_ data: Data) throws -> [ChartData] {
        let decoder = JSONDecoder()
        let historyResponse = try decoder.decode(PriceHistoryResponse.self, from: data)
        let chartData: [ChartData] = historyResponse.prices.compactMap { array in
            guard array.count >= 2 else { return nil }
            let timestamp = array[0]
            let price = array[1]
            let date = Date(timeIntervalSince1970: timestamp / 1000)
            return ChartData(date: date, price: price)
        }
        return chartData
    }
    
    private func localFileURL(for coinId: String, vsCurrency: String) -> URL {
        let fileName = "\(coinId)_\(vsCurrency)_365.json"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(fileName)
    }
    
    private func saveDataToLocalJSON(data: Data, for coinId: String, vsCurrency: String) {
        let fileURL = localFileURL(for: coinId, vsCurrency: vsCurrency)
        do {
            try data.write(to: fileURL)
        } catch {
            print("Fehler beim Speichern der lokalen JSON: \(error)")
        }
    }
    
    private func loadLocalJSON(for coinId: String, vsCurrency: String) -> Data? {
        let fileURL = localFileURL(for: coinId, vsCurrency: vsCurrency)
        return try? Data(contentsOf: fileURL)
    }
}
