import Foundation
import MapKit

public final class AreaGuideCloudKit {
    public static let shared = AreaGuideCloudKit()
    private init() {}

    public struct CloudAirport: Identifiable, Codable {
        public let id: UUID
        public let code: String
        public let name: String
        public let city: String
        public let state: String
        public let elevation: String
        public let latitude: Double
        public let longitude: Double
        public let unicom: String?
        public let phone: String?
        public let address: String?
        public let fboName: String?

        public init(id: UUID = UUID(), code: String, name: String, city: String, state: String, elevation: String, coordinate: CLLocationCoordinate2D, unicom: String? = nil, phone: String? = nil, address: String? = nil, fboName: String? = nil) {
            self.id = id
            self.code = code
            self.name = name
            self.city = city
            self.state = state
            self.elevation = elevation
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
            self.unicom = unicom
            self.phone = phone
            self.address = address
            self.fboName = fboName
        }

        public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    public struct CloudReview: Identifiable, Codable {
        public let id: UUID
        public let pilotName: String
        public let rating: Int
        public let date: Date
        public let title: String
        public let content: String
        public let tags: [String]

        public init(id: UUID = UUID(), pilotName: String, rating: Int, date: Date, title: String, content: String, tags: [String]) {
            self.id = id
            self.pilotName = pilotName
            self.rating = rating
            self.date = date
            self.title = title
            self.content = content
            self.tags = tags
        }
    }

    // MARK: - Public API (stubs)
    public func fetchAirports(matching text: String?) async throws -> [CloudAirport] {
        let all: [CloudAirport] = [
            CloudAirport(code: "KTEB", name: "Teterboro Airport", city: "Teterboro", state: "NJ", elevation: "8 ft", coordinate: CLLocationCoordinate2D(latitude: 40.8501, longitude: -74.0608)),
            CloudAirport(code: "KASE", name: "Aspen-Pitkin County", city: "Aspen", state: "CO", elevation: "7,820 ft", coordinate: CLLocationCoordinate2D(latitude: 39.2232, longitude: -106.8690)),
            CloudAirport(code: "KPBI", name: "Palm Beach Intl", city: "West Palm Beach", state: "FL", elevation: "19 ft", coordinate: CLLocationCoordinate2D(latitude: 26.6832, longitude: -80.0956))
        ]
        if let t = text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return all.filter { $0.code.localizedCaseInsensitiveContains(t) || $0.city.localizedCaseInsensitiveContains(t) }
        }
        return all
    }

    public func fetchReviews(for airportCode: String) async throws -> [CloudReview] {
        switch airportCode.uppercased() {
        case "KTEB":
            return [
                CloudReview(pilotName: "Capt. Sarah", rating: 4, date: Date(), title: "Busy but Efficient", content: "Meridian FBO is top notch. Expect delays during peak hours.", tags: ["FBO Service", "Fees"])
            ]
        case "KASE":
            return [
                CloudReview(pilotName: "JetJockey99", rating: 5, date: Date().addingTimeInterval(-86400*2), title: "Challenging Approach", content: "LOC DME-E can be tricky. Paragliders in summer.", tags: ["Approach", "FBO Service"])
            ]
        case "KPBI":
            return [
                CloudReview(pilotName: "Tom C.", rating: 5, date: Date().addingTimeInterval(-86400*10), title: "Great Overnight", content: "Excellent crew cars. Walkable food options.", tags: ["Overnight", "Crew Food"])
            ]
        default:
            return []
        }
    }

    public func saveReview(_ review: CloudReview, for airportCode: String) async throws {
        // Stub: In real implementation, save to CloudKit.
        // For now, just simulate a small delay.
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}
