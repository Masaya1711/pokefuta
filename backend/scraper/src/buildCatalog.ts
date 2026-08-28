import {
  fetchAreaPageHtml,
  fetchPrefecturePageHtml,
  fetchManholeDetailFragment,
  politeDelay,
} from "./shared/pokehutaClient";
import {
  parsePrefectureSlugsFromAreaPage,
  parseManholeIdsFromPrefecturePage,
  parseManholeDetail,
} from "./parseDetail";
import { ManholeCatalogEntry } from "./shared/types";

const AREA_IDS = [1, 2, 3, 4, 5, 6];

async function discoverAllManholeIds(): Promise<string[]> {
  const slugs = new Set<string>();

  for (const areaId of AREA_IDS) {
    const html = await fetchAreaPageHtml(areaId);
    for (const slug of parsePrefectureSlugsFromAreaPage(html)) {
      slugs.add(slug);
    }
    await politeDelay();
  }

  console.log(`discovered ${slugs.size} prefecture pages`);

  const ids = new Set<string>();
  for (const slug of slugs) {
    try {
      const html = await fetchPrefecturePageHtml(slug);
      for (const id of parseManholeIdsFromPrefecturePage(html)) {
        ids.add(id);
      }
    } catch (err) {
      console.warn(`failed to fetch prefecture page: ${slug}`, err);
    }
    await politeDelay();
  }

  return Array.from(ids);
}

async function fetchOneManhole(manholeId: string): Promise<ManholeCatalogEntry> {
  const fragment = await fetchManholeDetailFragment(manholeId);
  const parsed = parseManholeDetail(fragment);

  if (Number.isNaN(parsed.lat) || Number.isNaN(parsed.lng)) {
    throw new Error(`coordinates not found for manhole ${manholeId}`);
  }

  return {
    id: manholeId,
    prefName: parsed.prefName,
    city: parsed.city,
    address: parsed.address,
    lat: parsed.lat,
    lng: parsed.lng,
    pokemonList: parsed.pokemonList,
    description: parsed.description,
    imageUrl: parsed.imageUrlLarge,
    sourceUrl: `https://local.pokemon.jp/manhole/desc/${manholeId}/`,
  };
}

export interface BuildCatalogResult {
  entries: ManholeCatalogEntry[];
  failedIds: string[];
}

/**
 * local.pokemon.jp/manhole/ を巡回し、設置済み全ポケふたの情報を取得する。
 * 画像は自前でミラーリングせず、公式サイトのCDN画像URLをそのまま含める(ホットリンク)。
 */
export async function buildCatalog(): Promise<BuildCatalogResult> {
  const ids = await discoverAllManholeIds();
  console.log(`discovered ${ids.length} manholes in total`);

  const entries: ManholeCatalogEntry[] = [];
  const failedIds: string[] = [];

  for (const id of ids) {
    try {
      entries.push(await fetchOneManhole(id));
    } catch (err) {
      console.error(`failed to fetch manhole ${id}`, err);
      failedIds.push(id);
    }
    await politeDelay();
  }

  entries.sort((a, b) => Number(a.id) - Number(b.id));

  return { entries, failedIds };
}
