//
//  AppView.swift
//  CryptoTracker
//
//  Created by Michael Winkler on 17.03.25.
//

import SwiftUI

struct AppView: View {
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.currentUser == nil {
                AuthView(viewModel: authViewModel)
            } else {
                MainView()
            }
        }
    }
}

#Preview {
    AppView(authViewModel: AuthViewModel())
}
