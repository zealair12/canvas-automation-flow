//
//  AuthenticationView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Canvas Automation Flow")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your Canvas access token to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Canvas Access Token")
                        .font(.headline)
                    
                    TextField("Enter your Canvas token", text: $tokenInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text("You can find your token in Canvas: Account → Settings → Approved Integrations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: authenticateWithToken) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Authenticating..." : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tokenInput.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(tokenInput.isEmpty || isLoading)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func authenticateWithToken() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Use the direct token authentication
            let success = await apiService.authenticateWithToken(tokenInput)
            
            await MainActor.run {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    errorMessage = "Invalid token. Please check your Canvas access token."
                }
            }
        }
    }
}