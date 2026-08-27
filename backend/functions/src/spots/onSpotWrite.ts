import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

/**
 * おすすめスポット/飲食店レビューの追加・更新・削除のたびに、
 * 親ポケふたドキュメントの評価集計(件数・平均点)を再計算する。
 * 「件数や点数に応じて周囲のおすすめスポットとして表示する」ための並び替えキー。
 */
export const onSpotWrite = onDocumentWritten(
  { region: "asia-northeast1", document: "manholes/{manholeId}/spots/{spotId}" },
  async (event) => {
    const manholeId = event.params.manholeId;
    const db = getFirestore();

    const spotsSnapshot = await db
      .collection("manholes")
      .doc(manholeId)
      .collection("spots")
      .get();

    const ratings = spotsSnapshot.docs
      .map((doc) => doc.data().rating)
      .filter((rating): rating is number => typeof rating === "number");

    const count = ratings.length;
    const avgRating = count > 0 ? ratings.reduce((sum, r) => sum + r, 0) / count : 0;

    await db
      .collection("manholes")
      .doc(manholeId)
      .set(
        {
          spotRatingSummary: {
            count,
            avgRating: Math.round(avgRating * 10) / 10,
          },
        },
        { merge: true }
      );

    logger.info(`updated spotRatingSummary for ${manholeId}: count=${count} avg=${avgRating}`);
  }
);
