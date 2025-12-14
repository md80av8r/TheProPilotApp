// JumpseatChatView.swift - Real-time Chat for Jumpseat Coordination
// ProPilot App

import SwiftUI

struct JumpseatChatView: View {
    let channelId: String
    let channelName: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = JumpseatService.shared
    @StateObject private var settings = JumpseatSettings.shared
    
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages List
                    messagesScrollView
                    
                    // Input Bar
                    messageInputBar
                }
            }
            .navigationTitle(channelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                loadMessages()
            }
        }
    }
    
    // MARK: - Messages Scroll View
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(50)
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.authorId == service.currentUserId
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Messages Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Start the conversation!")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(50)
    }
    
    // MARK: - Message Input Bar
    
    private var messageInputBar: some View {
        HStack(spacing: 12) {
            // Text Field
            TextField("Type a message...", text: $newMessage)
                .foregroundColor(.white)
                .padding(12)
                .background(LogbookTheme.cardBackground)
                .cornerRadius(20)
            
            // Send Button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        newMessage.trimmingCharacters(in: .whitespaces).isEmpty ?
                        Color.gray.opacity(0.5) :
                        LogbookTheme.accentBlue
                    )
                    .clipShape(Circle())
            }
            .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(LogbookTheme.cardBackground.opacity(0.8))
    }
    
    // MARK: - Functions
    
    private func loadMessages() {
        // TODO: Load messages from Firebase
        isLoading = false
        
        // Sample messages for development
        #if DEBUG
        messages = [
            ChatMessage(
                channelId: channelId,
                authorId: "other",
                authorName: "Capt. Mike",
                content: "Hey, I'm scheduled to operate KLRD-KPTK tomorrow at 1430Z. Anyone need a ride?",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            ChatMessage(
                channelId: channelId,
                authorId: service.currentUserId ?? "me",
                authorName: settings.displayName,
                content: "That would be perfect! I'm trying to get back to the Detroit area.",
                timestamp: Date().addingTimeInterval(-3000)
            ),
            ChatMessage(
                channelId: channelId,
                authorId: "other",
                authorName: "Capt. Mike",
                content: "Great! We'll be at the USA Jet ramp. Text me when you arrive at LRD.",
                timestamp: Date().addingTimeInterval(-2400)
            )
        ]
        #endif
    }
    
    private func sendMessage() {
        let content = newMessage.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        
        let message = ChatMessage(
            channelId: channelId,
            authorId: service.currentUserId ?? "unknown",
            authorName: settings.displayName,
            content: content,
            timestamp: Date()
        )
        
        // Add locally immediately for responsiveness
        messages.append(message)
        newMessage = ""
        
        // TODO: Send to Firebase
        // service.sendMessage(message)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Author name (for others' messages)
                if !isFromCurrentUser {
                    Text(message.authorName)
                        .font(.caption.bold())
                        .foregroundColor(LogbookTheme.accentBlue)
                }
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser ?
                        LogbookTheme.accentBlue :
                        LogbookTheme.cardBackground
                    )
                    .cornerRadius(18)
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Chat Channels List View

struct ChatChannelsListView: View {
    @StateObject private var service = JumpseatService.shared
    
    @State private var channels: [ChatChannel] = []
    @State private var selectedChannel: ChatChannel?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                LogbookTheme.navy.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if channels.isEmpty {
                    emptyStateView
                } else {
                    channelsList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadChannels()
            }
            .sheet(item: $selectedChannel) { channel in
                JumpseatChatView(channelId: channel.id, channelName: channel.name)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Conversations")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("When you connect with other pilots about jumpseats, your conversations will appear here.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var channelsList: some View {
        List {
            ForEach(channels) { channel in
                Button {
                    selectedChannel = channel
                } label: {
                    ChannelRow(channel: channel)
                }
                .listRowBackground(LogbookTheme.cardBackground)
            }
        }
        .listStyle(.plain)
    }
    
    private func loadChannels() {
        // TODO: Load from Firebase
        isLoading = false
        
        #if DEBUG
        channels = [
            ChatChannel(
                type: .flight,
                name: "KLRD → KPTK",
                memberIds: ["me", "other"],
                lastMessageAt: Date().addingTimeInterval(-3600),
                lastMessagePreview: "Great! We'll be at the USA Jet ramp."
            ),
            ChatChannel(
                type: .route,
                name: "Detroit Area Pilots",
                memberIds: ["me", "pilot2", "pilot3"],
                lastMessageAt: Date().addingTimeInterval(-86400),
                lastMessagePreview: "Anyone know a good hotel near KYIP?"
            )
        ]
        #endif
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: ChatChannel
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(channelColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: channelIcon)
                        .foregroundColor(channelColor)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let lastMessageAt = channel.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let preview = channel.lastMessagePreview {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var channelIcon: String {
        switch channel.type {
        case .direct: return "person.fill"
        case .flight: return "airplane"
        case .route: return "map"
        case .general: return "bubble.left.and.bubble.right"
        }
    }
    
    private var channelColor: Color {
        switch channel.type {
        case .direct: return .blue
        case .flight: return .green
        case .route: return .orange
        case .general: return .purple
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}



// MARK: - Preview

#if DEBUG
struct JumpseatChatView_Previews: PreviewProvider {
    static var previews: some View {
        JumpseatChatView(channelId: "test", channelName: "KLRD → KPTK")
    }
}
#endif
