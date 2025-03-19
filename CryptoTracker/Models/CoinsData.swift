//
//  CoinsData.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 18.03.25.
//

import Foundation

struct CoinsData: Codable {
    let coins: [Crypto]
    let timestamp: Date
}
