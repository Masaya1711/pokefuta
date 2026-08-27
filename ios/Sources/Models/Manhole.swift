import Foundation
import FirebaseFirestore

struct PokemonRef: Codable, Hashable {
    var name: String
    var zukanNo: String
}

struct SpotRatingSummary: Codable, Hashable {
    var count: Int
    var avgRating: Double
}

struct Manhole: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var prefName: String
    var city: String
    var address: String
    var lat: Double
    var lng: Double
    var pokemonList: [PokemonRef]
    var description: String
    var imageUrl: String
    var sourceUrl: String
    var spotRatingSummary: SpotRatingSummary?

    var displayTitle: String {
        "\(prefName)/\(city)"
    }
}
