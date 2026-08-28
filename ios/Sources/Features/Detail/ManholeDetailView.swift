import SwiftUI

struct ManholeDetailView: View {
    let manhole: Manhole

    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var detailService: ManholeDetailService

    init(manhole: Manhole) {
        self.manhole = manhole
        _detailService = StateObject(wrappedValue: ManholeDetailService(manholeId: manhole.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: URL(string: manhole.imageUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))

                VStack(alignment: .leading, spacing: 8) {
                    Text(manhole.displayTitle)
                        .font(.title2.bold())
                    Text(manhole.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !manhole.pokemonList.isEmpty {
                        Text("掲載ポケモン: " + manhole.pokemonList.map(\.name).joined(separator: "、"))
                            .font(.subheadline)
                    }

                    Text(manhole.description)
                        .font(.body)
                        .padding(.top, 4)
                }
                .padding(.horizontal)

                CheckInSection(manhole: manhole, detailService: detailService)
                    .padding(.horizontal)

                Divider()

                PhotoGallerySection(photos: detailService.photos)
                    .padding(.horizontal)

                Divider()

                SpotListSection(detailService: detailService)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(manhole.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await detailService.refresh() }
    }
}
