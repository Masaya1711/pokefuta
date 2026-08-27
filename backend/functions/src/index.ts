import { initializeApp } from "firebase-admin/app";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { runManholeSync } from "./scraper/scrapeManholes";

initializeApp();

/** 毎日JST早朝4時に新着ポケふたを同期する。 */
export const syncManholesDaily = onSchedule(
  {
    schedule: "0 4 * * *",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const result = await runManholeSync();
    logger.info("daily sync finished", result);
  }
);

/**
 * 手動実行用(初期データ投入・動作確認用)。認証済みユーザーのみ呼び出し可能。
 * data.forceFull=true で全件を再取得する(通常は未登録分のみ)。
 */
export const syncManholesManual = onCall(
  { region: "asia-northeast1", timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "サインインが必要です。");
    }
    const forceFull = request.data?.forceFull === true;
    return runManholeSync({ forceFull });
  }
);

export { moderatePhoto } from "./moderation/moderatePhoto";
export { onSpotWrite } from "./spots/onSpotWrite";
