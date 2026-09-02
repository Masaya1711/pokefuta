import Foundation
import CloudKit

@MainActor
final class ManholeDetailService: ObservableObject {
    @Published var photos: [ManholePhoto] = []
    @Published var spots: [Spot] = []
    @Published var errorMessage: String?

    let manholeId: String
    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase

    /// CloudKitのPublic Databaseは保存直後のレコードが検索に出るまで時間がかかるため、
    /// 投稿した写真は手元でも保持し、取得結果と合成して表示する。
    private var locallyAddedPhotos: [ManholePhoto] = []

    init(manholeId: String) {
        self.manholeId = manholeId
    }

    /// 写真の投稿が成功した直後に呼ぶ。検索に出るのを待たずにギャラリーへ反映される。
    func insertUploadedPhoto(_ photo: ManholePhoto) {
        guard !locallyAddedPhotos.contains(where: { $0.id == photo.id }) else { return }
        locallyAddedPhotos.append(photo)
        photos = mergedPhotos(fetched: photos)
    }

    /// 取得結果に、まだ検索に出てこない投稿直後の写真を足す。
    private func mergedPhotos(fetched: [ManholePhoto]) -> [ManholePhoto] {
        let fetchedIds = Set(fetched.map(\.id))
        let pending = locallyAddedPhotos.filter { !fetchedIds.contains($0.id) }
        return (fetched + pending)
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var averageRating: Double {
        guard !spots.isEmpty else { return 0 }
        return Double(spots.reduce(0) { $0 + $1.rating }) / Double(spots.count)
    }

    func refresh() async {
        async let photosResult = fetchPhotos()
        async let spotsResult = fetchSpots()
        photos = mergedPhotos(fetched: await photosResult)
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

    /// 自分が投稿した写真を削除する。
    func deletePhoto(_ photo: ManholePhoto) async throws {
        _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: photo.id))
        locallyAddedPhotos.removeAll { $0.id == photo.id }
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
