import axios from "axios";

const BASE_URL = "https://local.pokemon.jp";
const USER_AGENT =
  "Mozilla/5.0 (compatible; PokeHutaCollectorBot/1.0; personal-use-app)";

// 詳細ページはX-Requested-Withヘッダーを付けないと、モーダル用フラグメントではなく
// サイト全体のシェルHTML(トップページ相当)が返ってきてしまう。
const ajaxHeaders = {
  "User-Agent": USER_AGENT,
  "X-Requested-With": "XMLHttpRequest",
};

const plainHeaders = {
  "User-Agent": USER_AGENT,
};

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchAreaPageHtml(areaId: number): Promise<string> {
  const res = await axios.get(`${BASE_URL}/manhole/area/${areaId}/`, {
    headers: plainHeaders,
    timeout: 15000,
  });
  return res.data as string;
}

export async function fetchPrefecturePageHtml(prefSlug: string): Promise<string> {
  const res = await axios.get(`${BASE_URL}/manhole/${prefSlug}.html`, {
    headers: plainHeaders,
    timeout: 15000,
  });
  return res.data as string;
}

export async function fetchManholeDetailFragment(manholeId: string): Promise<string> {
  const res = await axios.get(`${BASE_URL}/manhole/desc/${manholeId}/`, {
    params: { is_modal: 1 },
    headers: ajaxHeaders,
    timeout: 15000,
  });
  return res.data as string;
}

export async function fetchImageBuffer(imagePath: string): Promise<Buffer> {
  const url = imagePath.startsWith("http") ? imagePath : `${BASE_URL}${imagePath}`;
  const res = await axios.get(url, {
    headers: plainHeaders,
    responseType: "arraybuffer",
    timeout: 20000,
  });
  return Buffer.from(res.data);
}

/** サイトへの負荷を抑えるための固定ウェイト。連続リクエスト間に挿入する。 */
export async function politeDelay(): Promise<void> {
  await delay(250);
}
