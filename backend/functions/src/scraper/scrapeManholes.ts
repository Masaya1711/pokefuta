import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  fetchAreaPageHtml,
  fetchPrefecturePageHtml,
  fetchManholeDetailFragment,
  politeDelay,
} from "../shared/pokehutaClient";
import {
  parsePrefectureSlugsFromAreaPage,
  parseManholeIdsFromPrefecturePage,
  parseManholeDetail,
} from "./parseDetail";
import { mirrorManholeImage } from "./mirrorImage";

const AREA_IDS = [1, 2, 3, 4, 5, 6];
const MANHOLES_COLLECTION = "manholes";

export interface SyncResult {
  discoveredCount: number;
  newCount: number;
  failedIds: string[];
}

async function discoverAllManholeIds(): Promise<string[]> {
  const slugs = new Set<string>();

  for (const areaId of AREA_IDS) {
    const html = await fetchAreaPageHtml(areaId);
    for (const slug of parsePrefectureSlugsFromAreaPage(html)) {
      slugs.add(slug);
    }
    await politeDelay();
  }

  logger.info(`discovered ${slugs.size} prefecture pages`);

  const ids = new Set<string>();
  for (const slug of slugs) {
    try {
      const html = await fetchPrefecturePageHtml(slug);
      for (const id of parseManholeIdsFromPrefecturePage(html)) {
        ids.add(id);
      }
    } catch (err) {
      logger.warn(`failed to fetch prefecture page: ${slug}`, err);
    }
    await politeDelay();
  }

  return Array.from(ids);
}

async function getExistingManholeIds(): Promise<Set<string>> {
  const db = getFirestore();
  const snapshot = await db.collection(MANHOLES_COLLECTION).select().get();
  return new Set(snapshot.docs.map((doc) => doc.id));
}

async function syncOneManhole(manholeId: string): Promise<void> {
  const fragment = await fetchManholeDetailFragment(manholeId);
  const parsed = parseManholeDetail(fragment);

  if (Number.isNaN(parsed.lat) || Number.isNaN(parsed.lng)) {
    throw new Error(`coordinates not found for manhole ${manholeId}`);
  }

  const mirroredImageUrl = await mirrorManholeImage(manholeId, parsed.imageUrlLarge);

  const db = getFirestore();
  await db
    .collection(MANHOLES_COLLECTION)
    .doc(manholeId)
    .set({
      manholeId,
      prefName: parsed.prefName,
      city: parsed.city,
      address: parsed.address,
      lat: parsed.lat,
      lng: parsed.lng,
      pokemonList: parsed.pokemonList,
      description: parsed.description,
      imageUrl: mirroredImageUrl,
      sourceUrl: `https://local.pokemon.jp/manhole/desc/${manholeId}/`,
      createdAt: FieldValue.serverTimestamp(),
      syncedAt: FieldValue.serverTimestamp(),
    });
}

/**
 * local.pokemon.jp/manhole/ を巡回し、未登録のポケふたをFirestoreに追加する。
 * 既存分は既に登録済みのIDセットと突き合わせるだけで詳細再取得は行わない
 * (サイトへの負荷を抑えるため。全件の再取得はforceFullで実施)。
 */
export async function runManholeSync(options?: { forceFull?: boolean; maxItems?: number }): Promise<SyncResult> {
  const discoveredIds = await discoverAllManholeIds();
  const existingIds = options?.forceFull ? new Set<string>() : await getExistingManholeIds();

  let targetIds = discoveredIds.filter((id) => !existingIds.has(id));
  if (options?.maxItems) {
    targetIds = targetIds.slice(0, options.maxItems);
  }
  logger.info(`discovered=${discoveredIds.length} existing=${existingIds.size} new=${targetIds.length}`);

  const failedIds: string[] = [];
  for (const id of targetIds) {
    try {
      await syncOneManhole(id);
      logger.info(`synced manhole ${id}`);
    } catch (err) {
      logger.error(`failed to sync manhole ${id}`, err);
      failedIds.push(id);
    }
    await politeDelay();
  }

  return {
    discoveredCount: discoveredIds.length,
    newCount: targetIds.length - failedIds.length,
    failedIds,
  };
}
