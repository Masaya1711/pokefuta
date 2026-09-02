import Foundation
import CloudKit

@MainActor
final class ManholeDetailService: ObservableObject {
    @Published var photos: [ManholePhoto] = []
    @Published var spots: [Spot] = []
    @Published var errorMessage: String?

    let manholeId: String
    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase

    init(manholeId: String) {
        self.manholeId = manholeId
    }

    var averageRating: Double {
        guard !spots.isEmpty else { return 0 }
        return Double(spots.reduce(0) { $0 + $1.rating }) / Double(spots.count)
    }

    func refresh() async {
        async let photosResult = fetchPhotos()
        async let spotsResult = fetchSpots()
        photos = await photosResult
        spots = await spotsResult
    }

    // CloudKitはスキーマ側でSortable指定がない項目で並び替えるとクエリ全体が失敗するため、
    // 並び替えはサーバーに要求せずアプリ側で行う。
    private func fetchPhotos() async -> [ManholePhoto] {
        let predicate = NSPredicate(format: "manholeId == %@", manholeId)
        let query = CKQuery(recordType: "ManholePhoto", predicate: predicate)
        do {
            let (results, _) = try await db.records(matching: query)
            return results
                .compactMap { _, result -> ManholePhoto? in
                    guard case .success(let record) = result else { return nil }
                    return ManholePhoto(record: record)
                }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func fetchSpots() async -> [Spot] {
        let predicate = NSPredicate(format: "manholeId == %@", manholeId)
        let query = CKQuery(recordType: "Spot", predicate: predicate)
        do {
            let (results, _) = try await db.records(matching: query)
            return results
                .compactMap { _, result -> Spot? in
                    guard case .success(let record) = result else { return nil }
                    return Spot(record: record)
                }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func addSpot(ownerRecordName: String, name: String, category: SpotCategory, rating: Int, comment: String) async throws {
        let record = CKRecord(recordType: "Spot")
        record["manholeId"] = manholeId
        record["ownerRecordName"] = ownerRecordName
        record["name"] = name
        record["category"] = category.rawValue
        record["rating"] = Int64(rating)
        record["comment"] = comment
        _ = try await db.save(record)
        await refresh()
    }

    func addCheckin(ownerRecordName: String, method: CheckinMethod, distanceMeters: Double) async throws {
        let record = CKRecord(recordType: "Checkin")
        record["manholeId"] = manholeId
        record["ownerRecordName"] = ownerRecordName
        record["method"] = method.rawValue
        record["distanceMeters"] = distanceMeters
        _ = try await db.save(record)
    }
}
