import Foundation

struct PokemonRef: Codable, Hashable {
    var name: String
    var zukanNo: String
}

/// `data/manholes.json`(GitHub上に配置)から取得する静的カタログの1件分。
struct Manhole: Identifiable, Codable, Hashable {
    var id: String
    var prefName: String
    var city: String
    var address: String
    var lat: Double
    var lng: Double
    var pokemonList: [PokemonRef]
    var description: String
    var imageUrl: String
    var sourceUrl: String

    var displayTitle: String {
        "\(prefName)/\(city)"
    }
}
