//
//  SettingsViewModel.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 17.03.25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel = SettingsViewModel()
    @AppStorage("isDarkMode") var isDarkMode: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account Einstellungen")) {
                    TextField("Neue E-Mail", text: $viewModel.newEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("E-Mail aktualisieren") {
                        Task {
                            await viewModel.updateEmail()
                        }
                    }
                    
                    SecureField("Neues Passwort", text: $viewModel.newPassword)
                    Button("Passwort aktualisieren") {
                        Task {
                            await viewModel.updatePassword()
                        }
                    }
                }
                
                Section(header: Text("Darstellung")) {
                    Toggle(isOn: $isDarkMode) {
                        Text("Dark Mode")
                    }
                }
                
                Section {
                    Button("Abmelden") {
                        Task {
                            await viewModel.signOut()
                        }
                    }
                    .foregroundColor(.red)
                }
                
                if let message = viewModel.updateMessage {
                    Section {
                        Text(message)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}
