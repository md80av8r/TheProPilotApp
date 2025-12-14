// OPSCallWatchView.swift - OPS Call Watch Interface
import SwiftUI

struct OPSCallWatchView: View {
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("OPS Call")
                .font(.headline)
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Placeholder for OPS call functionality
            VStack(spacing: 4) {
                Button("Call OPS") {
                    // Placeholder action
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
                
                Text("No active flights")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("OPS")
    }
}
