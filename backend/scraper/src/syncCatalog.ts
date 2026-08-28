import * as fs from "fs";
import * as path from "path";
import { buildCatalog } from "./buildCatalog";

const OUTPUT_PATH = path.resolve(__dirname, "../../../data/manholes.json");

async function main(): Promise<void> {
  const { entries, failedIds } = await buildCatalog();

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(entries, null, 2), "utf-8");

  console.log(`wrote ${entries.length} entries to ${OUTPUT_PATH}`);
  if (failedIds.length > 0) {
    console.warn(`failed ids: ${failedIds.join(", ")}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
