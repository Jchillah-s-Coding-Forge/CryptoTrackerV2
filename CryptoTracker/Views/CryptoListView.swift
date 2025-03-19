//
//  CryptoListView.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 12.03.25.
//

import SwiftUI
import FirebaseFirestore

struct CryptoListView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var viewModel: CryptoListViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let lastUpdate = viewModel.lastUpdate {
                        Text("Update: \(DateFormatterUtil.formatDateToGermanStyle(lastUpdate))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text(viewModel.statusMessage)
                        .foregroundColor(viewModel.statusMessage.contains("Fehler") ? .red : .gray)
                        .padding(.horizontal)
                    
                    Picker("Währung", selection: $viewModel.selectedCurrency) {
                        ForEach(["usd", "eur", "gbp"], id: \.self) { currency in
                            Text(currency.uppercased()).tag(currency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedCurrency) { _, _ in
                        Task { await viewModel.fetchCoins() }
                    }
                    
                    if viewModel.coins.isEmpty {
                        Text("Keine Daten verfügbar.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(viewModel.coins) { coin in
                            NavigationLink(
                                destination: CryptoDetailView(
                                    coin: coin,
                                    currency: viewModel.selectedCurrency, 
                                    applyConversion: true, 
                                    viewModel: viewModel
                                )
                                .environmentObject(viewModel)
                                .environmentObject(favoritesViewModel)
                            ) {
                                CryptoRowView(coin: coin, currency: viewModel.selectedCurrency)
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.fetchCoins()
            }
            .navigationTitle("Krypto-Preise")
        }
    }
}

#Preview {
    CryptoListView()
        .environmentObject(FavoritesViewModel())
        .environmentObject(CryptoListViewModel())
}
