//
//  FavoritesManager.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 13.03.25.
//

import Foundation
import FirebaseAuth

@MainActor
class FavoritesManager: ObservableObject {
    @Published var favoriteIDs: Set<String> = []
    
    // Verwende das Repository direkt
    private let repository = FavoritesRepository.shared
    
    var userId: String? {
        Auth.auth().currentUser?.uid // 🔄 UID verwenden
    }
    
    var userEmail: String? {
        Auth.auth().currentUser?.email
    }
    
    init()  {
        loadFavorites()
    }
    
    func loadFavorites() {
        guard let userId = userId else {
            print("Kein angemeldeter Benutzer oder keine UID gefunden.")
            return
        }

        Task {
            do {
                let fetched = try await repository.fetchFavorites(for: userId) // 🔄 userId statt Email
                DispatchQueue.main.async {
                    self.favoriteIDs = fetched
                }
            } catch {
                print("Fehler beim Laden der Favoriten: \(error)")
            }
        }
    }
    
    func toggleFavorite(coin: Crypto) {
        guard let userId = userId else {
            print("Kein angemeldeter Benutzer oder keine UID gefunden.")
            return
        }

        if favoriteIDs.contains(coin.id) {
            favoriteIDs.remove(coin.id)
        } else {
            favoriteIDs.insert(coin.id)
        }
        persistFavorites(for: userId)
    }
    
    private func persistFavorites(for userId: String) {
        Task {
            do {
                try await repository.saveFavorites(
                    favorites: favoriteIDs,
                    for: userId,
                    userEmail: userEmail ?? "" 
                )
                print("Favoriten wurden gespeichert.")
            } catch {
                print("Fehler beim Speichern der Favoriten: \(error)")
            }
        }
    }
    
    func isFavorite(coin: Crypto) -> Bool {
        favoriteIDs.contains(coin.id)
    }
}
