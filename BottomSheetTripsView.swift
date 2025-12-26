// BottomSheetTripsView.swift - Draggable bottom sheet for trip history
import SwiftUI

struct BottomSheetTripsView: View {
    @ObservedObject var store: SwiftDataLogBookStore
    let onEdit: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Header
            HStack {
                Text("Trip History")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(store.trips.count) trips")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Trips list
            ScrollView {
                OrganizedLogbookView(store: store) { idx in
                    onEdit(idx)
                }
            }
        }
        .background(LogbookTheme.navy)
    }
}
