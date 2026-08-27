import SwiftUI

struct PhotoGallerySection: View {
    let photos: [ManholePhoto]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("みんなの写真")
                .font(.headline)

            if photos.isEmpty {
                Text("まだ写真がありません。最初の1枚を投稿してみましょう。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(photos) { photo in
                        AsyncImage(url: URL(string: photo.downloadUrl)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.secondarySystemBackground)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
