import Foundation

struct CrewMember: Identifiable, Codable, Equatable {
    var id: UUID
    var role: String
    var name: String
    var email: String
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case id, role, name, email
    }
    
    // Custom decoder to handle old data without id/email
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, or create new one if missing
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        
        // Decode required fields
        role = try container.decode(String.self, forKey: .role)
        name = try container.decode(String.self, forKey: .name)
        
        // Try to decode email, default to empty if missing
        email = (try? container.decode(String.self, forKey: .email)) ?? ""
    }
    
    // Standard encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
    }
    
    // Standard initializer for creating new crew members
    init(id: UUID = UUID(), role: String, name: String, email: String = "") {
        self.id = id
        self.role = role
        self.name = name
        self.email = email
    }
}
