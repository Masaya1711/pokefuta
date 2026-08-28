import * as cheerio from "cheerio";
import { ParsedManholeDetail, PokemonRef } from "./shared/types";

const BASE_URL = "https://local.pokemon.jp";

function toAbsoluteUrl(path: string): string {
  return path.startsWith("http") ? path : `${BASE_URL}${path}`;
}

function extractZukanNo(zukanUrl: string): string {
  const match = zukanUrl.match(/\/detail\/([^/?#]+)/);
  return match ? match[1] : "";
}

/**
 * `GET /manhole/desc/{id}/?is_modal=1` (X-Requested-Withヘッダー付き) が返す
 * モーダル用HTMLフラグメントをパースする。
 */
export function parseManholeDetail(html: string): ParsedManholeDetail {
  const $ = cheerio.load(html);
  const root = $(".detail-manhole");

  const heading = root.find(".heading h1").first().text().trim();
  const [prefName, city] = heading.split("/").map((s) => s.trim());

  const imageSrc = root.find(".heading img").first().attr("src") ?? "";
  const imageUrlLarge = toAbsoluteUrl(imageSrc);

  const pokemonList: PokemonRef[] = [];
  root.find(".zukan li a").each((_, el) => {
    const anchor = $(el);
    const name = anchor.find("span").first().text().trim();
    const zukanUrl = anchor.attr("href") ?? "";
    if (name) {
      pokemonList.push({ name, zukanNo: extractZukanNo(zukanUrl) });
    }
  });

  const address = root.find(".block.map p").first().text().trim();

  const mapHref = root.find(".googlemap-link a").first().attr("href") ?? "";
  const coordMatch = mapHref.match(/q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
  const lat = coordMatch ? parseFloat(coordMatch[1]) : NaN;
  const lng = coordMatch ? parseFloat(coordMatch[2]) : NaN;

  const description = root.find(".block.about p").first().text().trim();

  return {
    prefName: prefName ?? "",
    city: city ?? "",
    address,
    lat,
    lng,
    pokemonList,
    description,
    imageUrlLarge,
  };
}

/** 都道府県ページ(例: /manhole/toyama.html)から設置済みポケふたのIDを抽出する。 */
export function parseManholeIdsFromPrefecturePage(html: string): string[] {
  const $ = cheerio.load(html);
  const ids = new Set<string>();
  $('a.manhole-detail[href*="/manhole/desc/"]').each((_, el) => {
    const href = $(el).attr("href") ?? "";
    const match = href.match(/\/manhole\/desc\/(\d+)\//);
    if (match) {
      ids.add(match[1]);
    }
  });
  return Array.from(ids);
}

/** 地域トップページ(例: /manhole/area/1/)から都道府県ページのスラッグを抽出する。 */
export function parsePrefectureSlugsFromAreaPage(html: string): string[] {
  const $ = cheerio.load(html);
  const slugs = new Set<string>();
  $('a[href*="/manhole/"][href$=".html"]').each((_, el) => {
    const href = $(el).attr("href") ?? "";
    const match = href.match(/\/manhole\/([a-z0-9_-]+)\.html/);
    if (match) {
      slugs.add(match[1]);
    }
  });
  return Array.from(slugs);
}
