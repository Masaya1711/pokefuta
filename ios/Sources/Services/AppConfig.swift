import Foundation

enum AppConfig {
    static let manholeCatalogURL = URL(
        string: "https://raw.githubusercontent.com/Masaya1711/pokefuta/master/data/manholes.json"
    )!

    /// `CKContainer.default()`はApp IDに複数のiCloudコンテナが紐づいている場合に
    /// 意図しないものを選んでしまうことがあるため、明示的に指定する。
    static let cloudKitContainerIdentifier = "iCloud.com.kmtsjym.pokefuta"
}
