//
//  PriceData.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 12.03.25.
//

import Foundation

struct ChartData: Codable, Identifiable, Equatable {
    // Verwende den Zeitstempel als eindeutige ID
    var id: TimeInterval { date.timeIntervalSince1970 }
    let date: Date
    let price: Double
}
