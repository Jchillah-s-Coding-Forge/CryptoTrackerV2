//
//  PriceChartViewModel.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 12.03.25.
//

import Foundation

@MainActor
class PriceChartViewModel: ObservableObject {
    @Published var allPriceData: [ChartData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedCurrency: String = "usd" {
        didSet {
            applyConversionRate()
        }
    }
    
    // Conversion-Rates – hier als Beispiel, idealerweise zentral verwaltet (z. B. im CryptoListViewModel)
    var conversionRates: [String: Double] = ["usd": 1.0, "eur": 0.92, "gbp": 0.78]
    
    private let service = PriceHistoryService()
    
    /// Ruft den Preisverlauf für den Coin ab – dabei wird immer in USD abgerufen.
    func fetchPriceHistory(for coinId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // Hier rufst du den Preisverlauf in USD ab
            let data = try await service.fetchPriceHistory(for: coinId, vsCurrency: "usd")
            allPriceData = data
            applyConversionRate() // Umrechnung in die aktuell ausgewählte Währung
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    /// Berechnet den Conversion-Faktor basierend auf den Conversion-Rates.
    func conversionFactor() -> Double {
        let baseRate = conversionRates["usd"] ?? 1.0
        let targetRate = conversionRates[selectedCurrency.lowercased()] ?? 1.0
        return targetRate / baseRate
    }
    
    /// Wendet den Conversion-Faktor auf alle ChartData an.
    func applyConversionRate() {
        let factor = conversionFactor()
        // Hier wird für jeden ChartData-Eintrag der Preis umgerechnet.
        allPriceData = allPriceData.map { ChartData(date: $0.date, price: $0.price * factor) }
    }
    
    /// Filtert die Preisdaten für einen bestimmten Zeitraum.
    func filteredData(for duration: ChartDuration) -> [ChartData] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -duration.days, to: Date()) ?? Date()
        return allPriceData.filter { $0.date >= cutoffDate }
    }
}
