import SwiftUI

/// 地図上で個別ピンをタップした際に表示する簡易プレビュー。
/// カード本体をタップすると詳細画面に遷移し、右上のバツで閉じる。
struct ManholePreviewCard: View {
    let manhole: Manhole
    var onOpenDetail: () -> Void
    var onClose: () -> Void

    var body: some View {
        Button(action: onOpenDetail) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: URL(string: manhole.imageUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.secondarySystemBackground)
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(manhole.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(manhole.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.secondary, Color(.systemBackground))
            }
            .offset(x: 6, y: -6)
        }
    }
}
