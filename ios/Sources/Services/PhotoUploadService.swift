import Foundation
import CloudKit

struct PhotoUploadService {
    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase

    /// チェックイン写真をCloudKitの`ManholePhoto`レコードとして保存する(CKAsset)。
    func uploadCheckinPhoto(manholeId: String, ownerRecordName: String, imageData: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try imageData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let record = CKRecord(recordType: "ManholePhoto")
        record["manholeId"] = manholeId
        record["ownerRecordName"] = ownerRecordName
        record["asset"] = CKAsset(fileURL: tempURL)
        _ = try await db.save(record)
    }
}
