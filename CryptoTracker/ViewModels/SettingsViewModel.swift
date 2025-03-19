//
//  SettingsViewModel.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 17.03.25.
//

import SwiftUI
import FirebaseAuth

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var newEmail: String = ""
    @Published var newPassword: String = ""
    @Published var updateMessage: String? = nil
    @Published var isLoading: Bool = false

    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    
    func toggleDarkMode() {
        isDarkMode.toggle()
    }
    
    func updateEmail() async {
        guard let currentUser = Auth.auth().currentUser else {
            updateMessage = "Benutzer nicht gefunden."
            return
        }
        isLoading = true
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                currentUser.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            updateMessage = "Verifizierungs-E-Mail gesendet. Bitte folge den Anweisungen in der E-Mail, um deine Adresse zu aktualisieren."
        } catch {
            updateMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updatePassword() async {
        guard let currentUser = Auth.auth().currentUser else {
            updateMessage = "Benutzer nicht gefunden."
            return
        }
        isLoading = true
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                currentUser.updatePassword(to: newPassword) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            updateMessage = "Passwort erfolgreich aktualisiert."
        } catch {
            updateMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signOut() async {
        do {
            try AuthService.shared.signOut()
        } catch {
            updateMessage = error.localizedDescription
        }
    }
}
