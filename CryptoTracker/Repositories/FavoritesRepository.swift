//
//  FavoritesRepository.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 18.03.25.
//

import Foundation
import FirebaseFirestore

class FavoritesRepository {
    static let shared = FavoritesRepository()
    private let db = Firestore.firestore()
    
    private init() { }
    
    func saveFavorites(favorites: Set<String>, for userId: String, userEmail: String) async throws {
        let data: [String: Any] = [
            "favorites": Array(favorites),
            "email": userEmail
        ]
        try await db.collection("users").document(userId).setData(data, merge: true)
    }

    func fetchFavorites(for userId: String) async throws -> Set<String> {
        let document = try await db.collection("users").document(userId).getDocument()
        if let data = document.data(), let favIDs = data["favorites"] as? [String] {
            return Set(favIDs)
        }
        return []
    }

        func deleteFavorites(for userId: String) async throws {
        try await db.collection("users").document(userId).updateData(["favorites": FieldValue.delete()])
    }
}
