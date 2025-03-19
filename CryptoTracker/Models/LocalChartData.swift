//
//  LocalPriceData.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 18.03.25.
//

import Foundation

struct LocalChartData: Codable {
    let data: [ChartData]
    let lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case data, lastUpdated
    }
    
    // Benutzerdefinierter Initializer
    init(data: [ChartData], lastUpdated: Date? = Date()) {
        self.data = data
        self.lastUpdated = lastUpdated
    }
}
