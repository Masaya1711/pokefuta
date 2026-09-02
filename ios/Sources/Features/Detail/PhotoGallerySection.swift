import SwiftUI

struct PhotoGallerySection: View {
    @ObservedObject var detailService: ManholeDetailService
    let manholeId: String

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var photoHistoryService: PhotoHistoryService

    @State private var photoToDelete: ManholePhoto?
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    private func isOwn(_ photo: ManholePhoto) -> Bool {
        photo.ownerRecordName == authService.userRecordName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("みんなの写真")
                .font(.headline)

            if detailService.photos.isEmpty {
                Text("まだ写真がありません。最初の1枚を投稿してみましょう。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("自分が投稿した写真は長押しで削除できます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(detailService.photos) { photo in
                        Group {
                            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color(.secondarySystemBackground)
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .topTrailing) {
                            if isOwn(photo) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                                    .padding(4)
                            }
                        }
                        .contextMenu {
                            if isOwn(photo) {
                                Button(role: .destructive) {
                                    photoToDelete = photo
                                } label: {
                                    Label("この写真を削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if isDeleting {
                ProgressView()
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "この写真を削除しますか?",
            isPresented: Binding(
                get: { photoToDelete != nil },
                set: { if !$0 { photoToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let photoToDelete { delete(photoToDelete) }
            }
            Button("キャンセル", role: .cancel) { photoToDelete = nil }
        }
    }

    private func delete(_ photo: ManholePhoto) {
        isDeleting = true
        errorMessage = nil

        Task {
            do {
                try await detailService.deletePhoto(photo)
                // 自分の写真が1枚も残っていなければ、地図の色分けと一覧からも外す。
                if !detailService.photos.contains(where: { isOwn($0) }) {
                    photoHistoryService.markRemoved(manholeId: manholeId)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            photoToDelete = nil
            isDeleting = false
        }
    }
}
