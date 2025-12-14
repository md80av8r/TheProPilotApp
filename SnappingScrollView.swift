//
//  SnappingScrollView.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 11/15/25.
//


//
//  SnappingScrollView.swift
//  TheProPilotApp
//
//  Snapping scroll view that snaps each row into place
//  Created by Jeffrey Kadans on 11/15/25.
//

import SwiftUI

/// A scroll view wrapper that snaps to discrete positions
struct SnappingScrollView<Content: View>: View {
    let content: Content
    let itemHeight: CGFloat
    let spacing: CGFloat
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    
    init(itemHeight: CGFloat, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.itemHeight = itemHeight
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "scroll")
    }
}

/// Extension to add snapping behavior to any ScrollView
extension View {
    func snappingScrollBehavior(itemHeight: CGFloat, spacing: CGFloat = 8) -> some View {
        self.modifier(SnappingScrollModifier(itemHeight: itemHeight, spacing: spacing))
    }
}

struct SnappingScrollModifier: ViewModifier {
    let itemHeight: CGFloat
    let spacing: CGFloat
    
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Alternative: Native iOS 17+ Approach

/// For iOS 17+, use the native scrollTargetBehavior
@available(iOS 17.0, *)
struct ModernSnappingScrollView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Trip List with Snapping

/// Wrapper for the trip list that adds snapping behavior
struct SnappingTripListView: View {
    let trips: [Trip]
    let onEdit: (Trip) -> Void
    
    var body: some View {
        if #available(iOS 17.0, *) {
            // Use native snapping on iOS 17+
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(trips) { trip in
                        EnhancedLogbookRow(trip: trip, onEdit: { onEdit(trip) })
                            .containerRelativeFrame(.vertical, count: 1, spacing: 8)
                            .scrollTransition { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.8)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        } else {
            // Fallback for earlier iOS versions
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(trips) { trip in
                        EnhancedLogbookRow(trip: trip, onEdit: { onEdit(trip) })
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Integration Example

/*
 In ContentView.swift, replace your trip list ScrollView with:
 
 // OLD:
 ScrollView {
     LazyVStack(spacing: 8) {
         ForEach(filteredTrips) { trip in
             EnhancedLogbookRow(trip: trip, onEdit: { 
                 selectedTrip = trip
                 showingEditSheet = true
             })
         }
     }
 }
 
 // NEW:
 SnappingTripListView(
     trips: filteredTrips,
     onEdit: { trip in
         selectedTrip = trip
         showingEditSheet = true
     }
 )
 
 */

// MARK: - Custom Snapping Scroll View (iOS 15+)

/// Custom implementation with manual snapping for iOS 15+
struct CustomSnappingScrollView<Content: View>: View {
    let content: Content
    let itemHeight: CGFloat
    
    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0
    
    init(itemHeight: CGFloat = 100, @ViewBuilder content: () -> Content) {
        self.itemHeight = itemHeight
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.preference(
                                    key: ViewOffsetKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                            }
                        )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ViewOffsetKey.self) { offset in
                    // Calculate nearest snap point
                    let itemWithSpacing = itemHeight + 8 // 8 is spacing
                    let rawIndex = -offset / itemWithSpacing
                    let nearestIndex = round(rawIndex)
                    
                    // Only snap when user stops dragging
                    if abs(nearestIndex - rawIndex) < 0.1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentIndex = Int(nearestIndex)
                        }
                    }
                }
            }
        }
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Usage Examples

struct SnappingScrollExamples: View {
    let trips = [Trip]() // Your trips array
    
    var body: some View {
        VStack {
            Text("Trip List with Snapping")
                .font(.headline)
            
            // iOS 17+ Modern approach (RECOMMENDED)
            if #available(iOS 17.0, *) {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(trips) { trip in
                            EnhancedLogbookRow(trip: trip, onEdit: {})
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.85)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: - Simple Page-Style Snapping (Alternative)

/// Simple page-style snapping that snaps one full row at a time
struct PageSnappingScrollView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            ScrollView {
                content
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
        } else {
            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
        }
    }
}