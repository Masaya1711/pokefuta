import Foundation
import FirebaseStorage
import FirebaseFirestore

enum PhotoUploadError: Error {
    case notSignedIn
    case encodingFailed
}

struct PhotoUploadService {
    private let storage = Storage.storage()
    private let db = Firestore.firestore()

    /// チェックイン写真をStorageへアップロードし、Firestoreにドキュメントを作成する。
    /// アップロード直後はmoderationStatus=pendingで登録し、
    /// バックエンドのCloud Vision審査完了後にapproved/rejectedへ更新される。
    func uploadCheckinPhoto(manholeId: String, userId: String, imageData: Data) async throws -> String {
        let photoId = UUID().uuidString
        let storagePath = "manholePhotos/\(manholeId)/\(userId)/\(photoId).jpg"
        let ref = storage.reference(withPath: storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadUrl = try await ref.downloadURL()

        let photo = ManholePhoto(
            userId: userId,
            storagePath: storagePath,
            downloadUrl: downloadUrl.absoluteString,
            moderationStatus: .pending
        )

        try db
            .collection("manholes")
            .document(manholeId)
            .collection("photos")
            .document(photoId)
            .setData(from: photo)

        return photoId
    }
}
