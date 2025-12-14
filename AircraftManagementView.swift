// AircraftManagementView.swift - Aircraft Fleet Management
import SwiftUI

struct AircraftManagementView: View {
    @AppStorage("savedAircraft") private var savedAircraftData: Data = Data()
    @State private var aircraftList: [String] = []
    @State private var newAircraft = ""
    @State private var showingAddAlert = false
    @State private var showingAreaGuide = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(aircraftList, id: \.self) { aircraft in
                        HStack {
                            Image(systemName: "airplane")
                                .foregroundColor(LogbookTheme.accentBlue)
                                .frame(width: 25)
                            
                            Text(aircraft)
                                .font(.title3)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteAircraft)
                    
                    Button(action: {
                        showingAddAlert = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .frame(width: 25)
                            
                            Text("Add Aircraft")
                                .foregroundColor(LogbookTheme.accentGreen)
                                .font(.title3)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Fleet Aircraft")
                        .foregroundColor(.white)
                } footer: {
                    Text("Swipe left to delete aircraft. These will appear in the aircraft dropdown when creating trips.")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .background(LogbookTheme.navy.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Aircraft Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAreaGuide = true
                    } label: {
                        Label("Area Guide", systemImage: "airplane.departure")
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
        
        .alert("Add Aircraft", isPresented: $showingAddAlert) {
            TextField("N-Number (e.g., N123AB)", text: $newAircraft)
                .textCase(.uppercase)
            Button("Add") {
                addAircraft()
            }
            .disabled(newAircraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newAircraft = ""
            }
        } message: {
            Text("Enter the aircraft tail number (N-Number)")
        }
        .onAppear {
            loadAircraft()
        }
    }
    
    private func loadAircraft() {
        aircraftList = (try? JSONDecoder().decode([String].self, from: savedAircraftData)) ?? []
    }
    
    private func saveAircraft() {
        if let encoded = try? JSONEncoder().encode(aircraftList) {
            savedAircraftData = encoded
        }
    }
    
    private func addAircraft() {
        let cleanedAircraft = newAircraft.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !cleanedAircraft.isEmpty,
              !aircraftList.contains(cleanedAircraft) else {
            newAircraft = ""
            return
        }
        
        aircraftList.append(cleanedAircraft)
        aircraftList.sort()
        saveAircraft()
        newAircraft = ""
    }
    
    private func deleteAircraft(at offsets: IndexSet) {
        aircraftList.remove(atOffsets: offsets)
        saveAircraft()
    }
}

#Preview {
    AircraftManagementView()
}
