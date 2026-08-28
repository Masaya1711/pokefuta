import Foundation

/// `data/manholes.json`(GitHub上の静的カタログ)をHTTP経由で取得する。
/// サーバー・DBを持たず、依頼を受けたタイミングで手動更新されるファイルを読みに行くだけ。
@MainActor
final class ManholeRepository: ObservableObject {
    @Published var manholes: [Manhole] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let (data, _) = try await URLSession.shared.data(from: AppConfig.manholeCatalogURL)
            manholes = try JSONDecoder().decode([Manhole].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
