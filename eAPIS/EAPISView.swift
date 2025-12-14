//
//  EAPISView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/4/25.
//


import SwiftUI

struct EAPISView: View {
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    @State private var selectedTab = 0
    @State private var showingAddPassenger = false
    @State private var showingAddManifest = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Picker
                Picker("View", selection: $selectedTab) {
                    Label("Passengers", systemImage: "person.2.fill")
                        .tag(0)
                    Label("Manifests", systemImage: "doc.text.fill")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    PassengerListView()
                        .tag(0)
                    
                    ManifestListView()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("EAPIS")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if selectedTab == 0 {
                            showingAddPassenger = true
                        } else {
                            showingAddManifest = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await cloudKitManager.performFullSync()
                        }
                    } label: {
                        Image(systemName: cloudKitManager.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath")
                            .rotationEffect(.degrees(cloudKitManager.isSyncing ? 360 : 0))
                            .animation(cloudKitManager.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: cloudKitManager.isSyncing)
                    }
                    .disabled(cloudKitManager.isSyncing)
                }
            }
            .sheet(isPresented: $showingAddPassenger) {
                AddEditPassengerView(passenger: nil)
            }
            .sheet(isPresented: $showingAddManifest) {
                AddEditManifestView(manifest: nil)
            }
        }
    }
}

// MARK: - Passenger List View
struct PassengerListView: View {
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    @State private var searchText = ""
    @State private var selectedPassenger: Passenger?
    @State private var showingDetail = false
    
    var filteredPassengers: [Passenger] {
        if searchText.isEmpty {
            return cloudKitManager.passengers
        } else {
            return cloudKitManager.passengers.filter { passenger in
                passenger.fullName.localizedCaseInsensitiveContains(searchText) ||
                passenger.passportNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            if cloudKitManager.passengers.isEmpty {
                emptyStateView
            } else {
                List {
                    // Favorites Section
                    let favorites = filteredPassengers.filter { $0.isFavorite }
                    if !favorites.isEmpty {
                        Section("Favorites") {
                            ForEach(favorites) { passenger in
                                PassengerRowView(passenger: passenger)
                                    .onTapGesture {
                                        selectedPassenger = passenger
                                        showingDetail = true
                                    }
                            }
                        }
                    }
                    
                    // All Passengers Section
                    Section("All Passengers (\(filteredPassengers.count))") {
                        ForEach(filteredPassengers) { passenger in
                            PassengerRowView(passenger: passenger)
                                .onTapGesture {
                                    selectedPassenger = passenger
                                    showingDetail = true
                                }
                        }
                        .onDelete(perform: deletePassenger)
                    }
                }
                .searchable(text: $searchText, prompt: "Search passengers")
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let passenger = selectedPassenger {
                PassengerDetailView(passenger: passenger)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Passengers")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add passengers to quickly generate international flight manifests")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func deletePassenger(at offsets: IndexSet) {
        for index in offsets {
            let passenger = filteredPassengers[index]
            Task {
                try? await cloudKitManager.deletePassenger(passenger)
            }
        }
    }
}

// MARK: - Passenger Row View
struct PassengerRowView: View {
    let passenger: Passenger
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(passenger.fullName)
                        .font(.headline)
                    
                    if passenger.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 8) {
                    Label(passenger.nationality, systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("Passport: \(passenger.passportNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if passenger.passportExpiresWithin6Months {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Passport expires soon")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Manifest List View
struct ManifestListView: View {
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    @State private var selectedManifest: EAPISManifest?
    @State private var showingDetail = false
    @State private var selectedFilter: ManifestFilter = .all
    
    enum ManifestFilter: String, CaseIterable {
        case all = "All"
        case draft = "Draft"
        case ready = "Ready"
        case filed = "Filed"
    }
    
    var filteredManifests: [EAPISManifest] {
        switch selectedFilter {
        case .all:
            return cloudKitManager.manifests
        case .draft:
            return cloudKitManager.manifests.filter { $0.status == .draft }
        case .ready:
            return cloudKitManager.manifests.filter { $0.status == .readyToFile }
        case .filed:
            return cloudKitManager.manifests.filter { $0.status == .filed }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ManifestFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // List
            if filteredManifests.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredManifests) { manifest in
                        ManifestRowView(manifest: manifest)
                            .onTapGesture {
                                selectedManifest = manifest
                                showingDetail = true
                            }
                    }
                    .onDelete(perform: deleteManifest)
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let manifest = selectedManifest {
                ManifestDetailView(manifest: manifest)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Manifests")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create manifests for your international flights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func deleteManifest(at offsets: IndexSet) {
        for index in offsets {
            let manifest = filteredManifests[index]
            Task {
                try? await cloudKitManager.deleteManifest(manifest)
            }
        }
    }
}

// MARK: - Manifest Row View
struct ManifestRowView: View {
    let manifest: EAPISManifest
    @StateObject private var cloudKitManager = EAPISCloudKitManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Flight Number and Status
                HStack {
                    Text(manifest.flightNumber)
                        .font(.headline)
                    
                    Spacer()
                    
                    StatusBadge(status: manifest.status)
                }
                
                // Route
                HStack(spacing: 4) {
                    Text(manifest.departureAirport)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(manifest.arrivalAirport)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Date and Passengers
                HStack(spacing: 8) {
                    Label(formatDate(manifest.departureDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Label("\(manifest.totalPassengers) PAX", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: EAPISManifest.ManifestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .draft:
            return .gray
        case .readyToFile:
            return .orange
        case .filed:
            return .green
        case .archived:
            return .blue
        }
    }
}

#Preview {
    EAPISView()
}