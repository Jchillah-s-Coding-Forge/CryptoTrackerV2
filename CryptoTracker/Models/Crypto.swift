//
//  Crypto.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 12.03.25.
//

import Foundation
import FirebaseFirestore

struct Crypto: Identifiable, Codable, Equatable {
    @DocumentID var documentID: String?  
    let id: String  
    let symbol: String
    let name: String
    let image: String
    var currentPrice: Double
    var marketCap: Double
    let marketCapRank: Int
    var volume: Double
    var high24h: Double
    var low24h: Double
    let priceChange24h: Double
    let priceChangePercentage24h: Double
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case volume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case lastUpdated = "last_updated"
    }
    
    // Equatable: Vergleiche alle Properties außer documentID.
    static func == (lhs: Crypto, rhs: Crypto) -> Bool {
        return lhs.id == rhs.id &&
            lhs.symbol == rhs.symbol &&
            lhs.name == rhs.name &&
            lhs.image == rhs.image &&
            lhs.currentPrice == rhs.currentPrice &&
            lhs.marketCap == rhs.marketCap &&
            lhs.marketCapRank == rhs.marketCapRank &&
            lhs.volume == rhs.volume &&
            lhs.high24h == rhs.high24h &&
            lhs.low24h == rhs.low24h &&
            lhs.priceChange24h == rhs.priceChange24h &&
            lhs.priceChangePercentage24h == rhs.priceChangePercentage24h &&
            lhs.lastUpdated == rhs.lastUpdated
    }
}
