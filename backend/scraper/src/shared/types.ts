export interface PokemonRef {
  name: string;
  zukanNo: string;
}

/** iOSアプリの`Manhole`モデルとフィールド名を一致させたカタログ1件分の形式。 */
export interface ManholeCatalogEntry {
  id: string;
  prefName: string;
  city: string;
  address: string;
  lat: number;
  lng: number;
  pokemonList: PokemonRef[];
  description: string;
  imageUrl: string;
  sourceUrl: string;
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
