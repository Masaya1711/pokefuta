export interface PokemonRef {
  name: string;
  zukanNo: string;
}

export interface ManholeImageUrls {
  s: string;
  m: string;
  l: string;
}

export interface ManholeDoc {
  manholeId: string;
  prefName: string;
  city: string;
  address: string;
  lat: number;
  lng: number;
  pokemonList: PokemonRef[];
  description: string;
  imageUrls: ManholeImageUrls;
  sourceUrl: string;
  syncedAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.FieldValue | FirebaseFirestore.Timestamp;
}

export interface ParsedManholeDetail {
  prefName: string;
  city: string;
  address: string;
  lat: number;
  lng: number;
  pokemonList: PokemonRef[];
  description: string;
  imageUrlLarge: string;
}
