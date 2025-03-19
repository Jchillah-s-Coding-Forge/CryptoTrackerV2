import Foundation
import FirebaseFirestore

@MainActor
class CryptoListViewModel: ObservableObject {
    @Published var conversionRates: [String: Double] = ["usd": 1.0, "eur": 0.92, "gbp": 0.78]
    @Published var coins: [Crypto] = []
    @Published var favoriteCoins: [String] = []
    @Published var statusMessage: String = "Laden…"
    @Published var selectedCurrency: String = "usd" {
        didSet {
            applyConversionRate()
        }
    }
    @Published var lastUpdate: Date? = nil

    private let baseCurrency: String = "usd"
    private let cryptoService = CryptoService()
    private let firestoreService = CryptoCoinsRepository.shared
    private var originalCoins: [Crypto] = []
    private let throttleInterval: TimeInterval = 60

    var allOriginalCoins: [Crypto] {
        return originalCoins
    }

    init() {
        Task {
            await fetchExchangeRates()
            await fetchCoins()
            startTimer()
        }
    }
    
    func conversionFactor(for currency: String) -> Double {
        let baseRate = cryptoService.getConversionRate(for: baseCurrency)
        let targetRate = cryptoService.getConversionRate(for: currency)
        return targetRate / baseRate
    }
    
    /// Lädt Coins: Falls keine Daten in Firestore vorhanden oder die Daten veraltet sind, werden die Daten von der API abgerufen und gespeichert.
    func fetchCoins() async {
        do {
            // Versuche, die Coins aus Firestore zu laden.
            let (firestoreCoins, firestoreTimestamp) = try await firestoreService.fetchAllCoins()
            
            // Prüfe, ob entweder keine Daten vorhanden sind oder der gespeicherte Timestamp veraltet ist.
            if firestoreCoins.isEmpty || Date().timeIntervalSince(firestoreTimestamp) > throttleInterval {
                statusMessage = "Lade neue Daten…"
                
                // Daten von der API abrufen.
                let fetchedCoins = try await cryptoService.fetchCryptoDataFromAPI(for: baseCurrency.uppercased())
                
                // Vergleiche, ob die abgerufenen Daten anders sind als die in Firestore.
                if fetchedCoins != firestoreCoins {
                    // Falls es Änderungen gibt, speichere diese in Firestore.
                    try await firestoreService.saveAllCoins(fetchedCoins)
                    try await firestoreService.setLastUpdatedTime()
                    
                    originalCoins = fetchedCoins
                    lastUpdate = Date()
                    applyConversionRate()
                    statusMessage = "Daten aktualisiert (Update: \(DateFormatterUtil.formatDateToGermanStyle(Date())))"
                } else {
                    // Falls die API-Daten identisch sind, werden keine Änderungen vorgenommen.
                    originalCoins = firestoreCoins
                    lastUpdate = firestoreTimestamp
                    applyConversionRate()
                    statusMessage = "Keine Änderungen vorhanden."
                }
            } else {
                // Falls die in Firestore gespeicherten Daten noch aktuell sind:
                originalCoins = firestoreCoins
                lastUpdate = firestoreTimestamp
                applyConversionRate()
                statusMessage = "Keine Änderungen vorhanden."
            }
        } catch {
            // Fehler beim Laden aus Firestore: Fallback zur API.
            statusMessage = "Fehler beim Laden aus Firestore: \(error.localizedDescription)"
            do {
                let fetchedCoins = try await cryptoService.fetchCryptoDataFromAPI(for: baseCurrency.uppercased())
                try await firestoreService.saveAllCoins(fetchedCoins)
                try await firestoreService.setLastUpdatedTime()
                originalCoins = fetchedCoins
                lastUpdate = Date()
                applyConversionRate()
                statusMessage = "Daten aktualisiert (Update: \(DateFormatterUtil.formatDateToGermanStyle(Date())))"
            } catch {
                statusMessage = "Fehler beim Aktualisieren: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchExchangeRates() async {
        do {
            try await cryptoService.fetchExchangeRatesFromAPI()
        } catch {
            print("Fehler beim Abrufen der Wechselkurse: \(error)")
        }
    }
    
    func applyConversionRate() {
        let factor = conversionFactor(for: selectedCurrency)
        coins = originalCoins.map { coin in
            Crypto(
                id: coin.id,
                symbol: coin.symbol,
                name: coin.name,
                image: coin.image,
                currentPrice: coin.currentPrice * factor,
                marketCap: coin.marketCap * factor,
                marketCapRank: coin.marketCapRank,
                volume: coin.volume * factor,
                high24h: coin.high24h * factor,
                low24h: coin.low24h * factor,
                priceChange24h: coin.priceChange24h * factor,
                priceChangePercentage24h: coin.priceChangePercentage24h,
                lastUpdated: coin.lastUpdated
            )
        }
    }
    
    func formattedPrice(for coin: Crypto) -> String {
        return CurrencyFormatter.formatPrice(coin.currentPrice, currencyCode: selectedCurrency.uppercased())
    }
    
    private func startTimer() {
        Task {
            while true {
                try await Task.sleep(nanoseconds: UInt64(throttleInterval * 1_000_000_000))
                await fetchCoins()
            }
        }
    }
    
    func loadFavorites(userId: String) async {
        do {
            favoriteCoins = try await firestoreService.getFavoriteCoins(userId: userId)
        } catch {
            print("Fehler beim Laden der Favoriten: \(error.localizedDescription)")
        }
    }
    
    func toggleFavorite(userId: String, coinId: String) async {
        if favoriteCoins.contains(coinId) {
            try? await firestoreService.removeFavoriteCoin(userId: userId, coinId: coinId)
            favoriteCoins.removeAll { $0 == coinId }
        } else {
            try? await firestoreService.addFavoriteCoin(userId: userId, coinId: coinId)
            favoriteCoins.append(coinId)
        }
    }
}
