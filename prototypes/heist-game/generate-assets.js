const fs = require("node:fs/promises");
const path = require("node:path");

const assetFolder = path.resolve(__dirname, "assets");
const envFilePath = path.resolve(__dirname, "..", "env.sh");

const assets = [
  {
    name: "floor",
    filename: "floor.png",
    prompt:
      "Top-down pixel art dungeon floor tile, 32x32 sprite, clean stone slabs, subtle cracks, consistent palette, crisp pixels, game-ready.",
  },
  {
    name: "wall",
    filename: "wall.png",
    prompt:
      "Top-down pixel art dungeon wall tile, 32x32 sprite, stone blocks, darker shading, slight highlights, consistent palette, crisp pixels, game-ready.",
  },
  {
    name: "player",
    filename: "player.png",
    prompt:
      "Top-down pixel art stealth thief character sprite, 32x32, wearing a dark outfit and mask, small backpack, consistent palette, crisp pixels.",
  },
  {
    name: "guard",
    filename: "guard.png",
    prompt:
      "Top-down pixel art security guard sprite, 32x32, uniform with cap, readable silhouette, consistent palette, crisp pixels.",
  },
  {
    name: "treasure",
    filename: "treasure.png",
    prompt:
      "Top-down pixel art treasure chest sprite, 32x32, warm gold accents, subtle shine, consistent palette, crisp pixels.",
  },
];

async function loadApiKey() {
  try {
    const contents = await fs.readFile(envFilePath, "utf-8");
    const match = contents.match(/OPENAI_API_KEY="([^"]+)"/);
    if (match?.[1]) {
      return match[1];
    }
  } catch (error) {
    console.error("Could not read env.sh", error);
  }
  if (process.env.OPENAI_API_KEY) {
    return process.env.OPENAI_API_KEY;
  }
  throw new Error("Missing OPENAI_API_KEY in env.sh or environment.");
}

async function generateImage(apiKey, prompt) {
  const response = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-image-1",
      prompt,
      size: "1024x1024",
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(errorText || "Image generation failed.");
  }

  const data = await response.json();
  const base64Image = data?.data?.[0]?.b64_json;
  if (!base64Image) {
    throw new Error("No image returned.");
  }

  return Buffer.from(base64Image, "base64");
}

async function ensureAssetsFolder() {
  await fs.mkdir(assetFolder, { recursive: true });
}

async function main() {
  const apiKey = await loadApiKey();
  await ensureAssetsFolder();

  for (const asset of assets) {
    console.log(`Generating ${asset.name}...`);
    const buffer = await generateImage(apiKey, asset.prompt);
    const filePath = path.resolve(assetFolder, asset.filename);
    await fs.writeFile(filePath, buffer);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
