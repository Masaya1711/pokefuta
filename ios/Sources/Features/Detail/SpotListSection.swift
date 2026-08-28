import SwiftUI

struct SpotListSection: View {
    @ObservedObject var detailService: ManholeDetailService

    @State private var showSpotForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("周辺のおすすめスポット")
                    .font(.headline)
                Spacer()
                Button {
                    showSpotForm = true
                } label: {
                    Label("投稿", systemImage: "plus.circle")
                }
                .font(.subheadline)
            }

            if !detailService.spots.isEmpty {
                Text(String(format: "平均%.1f点 (%d件)", detailService.averageRating, detailService.spots.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if detailService.spots.isEmpty {
                Text("まだ投稿がありません。おすすめのお店やスポットを教えてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detailService.spots) { spot in
                    SpotRow(spot: spot)
                }
            }
        }
        .sheet(isPresented: $showSpotForm) {
            SpotFormView(detailService: detailService)
        }
    }
}

private struct SpotRow: View {
    let spot: Spot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.name).font(.subheadline.bold())
                Spacer()
                RatingStars(rating: spot.rating)
            }
            Text(spot.category.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !spot.comment.isEmpty {
                Text(spot.comment).font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }
}
