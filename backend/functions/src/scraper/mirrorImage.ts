import { getStorage } from "firebase-admin/storage";
import { fetchImageBuffer } from "../shared/pokehutaClient";

/**
 * ポケモン公式CDN上の画像をFirebase Storageにミラーリングし、公開ダウンロードURLを返す。
 * 原本サイトの構成変更・削除に依存しないようにするため。
 */
export async function mirrorManholeImage(
  manholeId: string,
  sourceImagePath: string
): Promise<string> {
  const buffer = await fetchImageBuffer(sourceImagePath);
  const bucket = getStorage().bucket();
  const destination = `manholeImages/${manholeId}/l.png`;
  const file = bucket.file(destination);

  await file.save(buffer, {
    contentType: "image/png",
    metadata: {
      cacheControl: "public, max-age=31536000",
    },
  });
  await file.makePublic();

  return `https://storage.googleapis.com/${bucket.name}/${destination}`;
}
