import Foundation
import CloudKit
import CoreLocation

public struct CloudAirport {
    public let code: String
    public let name: String
    public let city: String
    public let state: String
    public let elevation: String
    public let coordinate: CLLocationCoordinate2D
    // Optional detail fields (populate if your schema includes them)
    public let unicom: String?
    public let phone: String?
    public let address: String?
    public let fboName: String?
}

public struct CloudReview {
    public let pilotName: String
    public let rating: Int
    public let date: Date
    public let title: String
    public let content: String
    public let tags: [String]
}

public final class AreaGuideCloudKit {
    public static let shared = AreaGuideCloudKit()
    private init() {}

    // Adjust if you use a custom container identifier
    private let container = CKContainer.default()
    private var database: CKDatabase { container.publicCloudDatabase }

    // Record type names and field keys – update if your schema differs
    private enum RecordType {
        static let airport = "Airport"
        static let review = "Review"
    }

    private enum AirportKeys {
        static let code = "code"
        static let name = "name"
        static let city = "city"
        static let state = "state"
        static let elevation = "elevation"
        static let location = "location" // CLLocation
        // Optional extras
        static let unicom = "unicom"
        static let phone = "phone"
        static let address = "address"
        static let fboName = "fboName"
    }

    private enum ReviewKeys {
        static let pilotName = "pilotName"
        static let rating = "rating"
        static let date = "date"
        static let title = "title"
        static let content = "content"
        static let tags = "tags" // [String]
        static let airportCode = "airportCode" // String, or use a CKReference if you prefer
    }

    // MARK: - Airports
    public func fetchAirports(matching text: String?) async throws -> [CloudAirport] {
        let predicate: NSPredicate
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let p1 = NSPredicate(format: "%K CONTAINS[cd] %@", AirportKeys.code, text)
            let p2 = NSPredicate(format: "%K CONTAINS[cd] %@", AirportKeys.city, text)
            predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [p1, p2])
        } else {
            predicate = NSPredicate(value: true)
        }

        let query = CKQuery(recordType: RecordType.airport, predicate: predicate)
        let records = try await performQuery(query)
        return records.compactMap { record in
            guard
                let code = record[AirportKeys.code] as? String,
                let name = record[AirportKeys.name] as? String,
                let city = record[AirportKeys.city] as? String,
                let state = record[AirportKeys.state] as? String,
                let elevation = record[AirportKeys.elevation] as? String,
                let location = record[AirportKeys.location] as? CLLocation
            else { return nil }

            return CloudAirport(
                code: code,
                name: name,
                city: city,
                state: state,
                elevation: elevation,
                coordinate: location.coordinate,
                unicom: record[AirportKeys.unicom] as? String,
                phone: record[AirportKeys.phone] as? String,
                address: record[AirportKeys.address] as? String,
                fboName: record[AirportKeys.fboName] as? String
            )
        }
    }

    // MARK: - Reviews
    public func fetchReviews(for code: String) async throws -> [CloudReview] {
        let predicate = NSPredicate(format: "%K == %@", ReviewKeys.airportCode, code)
        let query = CKQuery(recordType: RecordType.review, predicate: predicate)
        let records = try await performQuery(query)
        return records.compactMap { record in
            guard
                let pilotName = record[ReviewKeys.pilotName] as? String,
                let rating = record[ReviewKeys.rating] as? Int,
                let date = record[ReviewKeys.date] as? Date,
                let title = record[ReviewKeys.title] as? String,
                let content = record[ReviewKeys.content] as? String
            else { return nil }
            let tags = record[ReviewKeys.tags] as? [String] ?? []
            return CloudReview(
                pilotName: pilotName,
                rating: rating,
                date: date,
                title: title,
                content: content,
                tags: tags
            )
        }
    }

    public func saveReview(_ review: CloudReview, for code: String) async throws {
        let record = CKRecord(recordType: RecordType.review)
        record[ReviewKeys.pilotName] = review.pilotName as CKRecordValue
        record[ReviewKeys.rating] = review.rating as CKRecordValue
        record[ReviewKeys.date] = review.date as CKRecordValue
        record[ReviewKeys.title] = review.title as CKRecordValue
        record[ReviewKeys.content] = review.content as CKRecordValue
        record[ReviewKeys.tags] = review.tags as CKRecordValue
        record[ReviewKeys.airportCode] = code as CKRecordValue
        _ = try await database.save(record)
    }

    // MARK: - Helpers
    private func performQuery(_ query: CKQuery) async throws -> [CKRecord] {
        var results: [CKRecord] = []
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 100

        return try await withCheckedThrowingContinuation { continuation in
            operation.recordFetchedBlock = { record in
                results.append(record)
            }
            operation.queryResultBlock = { cursor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    if let cursor = cursor {
                        self.fetchAll(with: cursor, accumulated: results) { res in
                            continuation.resume(with: res)
                        }
                    } else {
                        continuation.resume(returning: results)
                    }
                }
            }
            self.database.add(operation)
        }
    }

    private func fetchAll(with cursor: CKQueryOperation.Cursor, accumulated: [CKRecord], completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        var results = accumulated
        let op = CKQueryOperation(cursor: cursor)
        op.resultsLimit = 100
        op.recordFetchedBlock = { record in results.append(record) }
        op.queryResultBlock = { nextCursor, error in
            if let error = error {
                completion(.failure(error))
            } else if let nextCursor = nextCursor {
                self.fetchAll(with: nextCursor, accumulated: results, completion: completion)
            } else {
                completion(.success(results))
            }
        }
        database.add(op)
    }
}
