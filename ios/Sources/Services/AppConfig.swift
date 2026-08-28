import Foundation

enum AppConfig {
    /// リポジトリ作成後、実際のGitHubユーザー名/リポジトリ名に置き換えること。
    static let manholeCatalogURL = URL(
        string: "https://raw.githubusercontent.com/kmtsjym/pokehuta/main/data/manholes.json"
    )!
}
