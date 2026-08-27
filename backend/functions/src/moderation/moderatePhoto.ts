import { onObjectFinalized } from "firebase-functions/v2/storage";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import vision from "@google-cloud/vision";

const visionClient = new vision.ImageAnnotatorClient();

const REJECT_LIKELIHOODS = new Set(["LIKELY", "VERY_LIKELY"]);

// manholePhotos/{manholeId}/{uid}/{photoId}
const PATH_PATTERN = /^manholePhotos\/([^/]+)\/([^/]+)\/([^/]+)$/;

/**
 * Storageへの写真アップロードをトリガーに、Cloud Vision SafeSearchで
 * 不適切な画像でないかを事前自動モデレーションする。
 */
export const moderatePhoto = onObjectFinalized(
  { region: "asia-northeast1" },
  async (event) => {
    const filePath = event.data.name;
    const match = filePath.match(PATH_PATTERN);
    if (!match) {
      return;
    }

    const [, manholeId, , photoId] = match;
    const bucketName = event.data.bucket;
    const gcsUri = `gs://${bucketName}/${filePath}`;

    const photoRef = getFirestore()
      .collection("manholes")
      .doc(manholeId)
      .collection("photos")
      .doc(photoId);

    try {
      const [result] = await visionClient.safeSearchDetection(gcsUri);
      const detection = result.safeSearchAnnotation;

      const isRejected =
        !!detection &&
        [detection.adult, detection.violence, detection.racy].some(
          (likelihood) => likelihood && REJECT_LIKELIHOODS.has(String(likelihood))
        );

      if (isRejected) {
        logger.warn(`rejected photo ${filePath}`, detection);
        await getStorage().bucket(bucketName).file(filePath).delete({ ignoreNotFound: true });
        await photoRef.set({ moderationStatus: "rejected" }, { merge: true });
      } else {
        await photoRef.set({ moderationStatus: "approved" }, { merge: true });
      }
    } catch (err) {
      logger.error(`moderation failed for ${filePath}`, err);
      // 解析自体に失敗した場合は安全側に倒し、手動確認待ちのまま(pending)にしておく。
    }
  }
);
