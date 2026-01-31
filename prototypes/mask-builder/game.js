const levels = [
  { target: 12, plays: 8 },
  { target: 18, plays: 7 },
  { target: 24, plays: 6 },
];

const slotLabels = {
  base: "Base",
  eyes: "Eyes",
  nose: "Nose",
  mouth: "Mouth",
  adornment: "Adornment",
};

const cardTemplates = [
  { name: "Porcelain Base", slot: "base", quality: 4, text: "Smooth and clean." },
  { name: "Obsidian Base", slot: "base", quality: 5, text: "Deep and glossy." },
  { name: "Driftwood Base", slot: "base", quality: 3, text: "Weathered charm." },
  { name: "Moonlit Eyes", slot: "eyes", quality: 4, text: "Soft glimmer." },
  { name: "Crimson Eyes", slot: "eyes", quality: 3, text: "Bold stare." },
  { name: "Amber Eyes", slot: "eyes", quality: 2, text: "Warm gaze." },
  { name: "Carved Nose", slot: "nose", quality: 3, text: "Balanced form." },
  { name: "Bejeweled Nose", slot: "nose", quality: 4, text: "Sparkling centerpiece." },
  { name: "Feathered Mouth", slot: "mouth", quality: 3, text: "Light and airy." },
  { name: "Steel Mouth", slot: "mouth", quality: 4, text: "Sharp edge." },
  { name: "Golden Smile", slot: "mouth", quality: 5, text: "Radiant finish." },
  { name: "Violet Crown", slot: "adornment", quality: 4, text: "Regal touch." },
  { name: "Lantern Halo", slot: "adornment", quality: 3, text: "Soft aura." },
  { name: "Bone Spikes", slot: "adornment", quality: 5, text: "Fearsome detail." },
];

const handSize = 5;
const fullMaskBonus = 3;

let levelIndex = 0;
let deck = [];
let hand = [];
let mask = {};
let playsLeft = 0;
let status = "playing";
let generatedImageSignature = "";
let isGeneratingImage = false;
const OPENAI_API_KEY =
  "<OPENAI_API_KEY>";

const maskGrid = document.getElementById("maskGrid");
const handEl = document.getElementById("hand");
const scoreLabel = document.getElementById("scoreLabel");
const playsLabel = document.getElementById("playsLabel");
const deckLabel = document.getElementById("deckLabel");
const handLabel = document.getElementById("handLabel");
const levelLabel = document.getElementById("levelLabel");
const targetLabel = document.getElementById("targetLabel");
const bonusLabel = document.getElementById("bonusLabel");
const message = document.getElementById("message");
const imageStatus = document.getElementById("imageStatus");
const generatedImage = document.getElementById("generatedImage");
const resetButton = document.getElementById("resetButton");
const nextButton = document.getElementById("nextButton");

function buildDeck() {
  const cards = [];
  let id = 0;

  for (const template of cardTemplates) {
    const copies = template.quality >= 5 ? 1 : 2;
    for (let i = 0; i < copies; i += 1) {
      cards.push({ ...template, id: id++ });
    }
  }

  return shuffle(cards);
}

function shuffle(array) {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

function resetMask() {
  mask = {
    base: null,
    eyes: null,
    nose: null,
    mouth: null,
    adornment: null,
  };
}

function resetGeneratedImage() {
  generatedImageSignature = "";
  isGeneratingImage = false;
  imageStatus.textContent = "Complete the mask to generate art.";
  generatedImage.removeAttribute("src");
  generatedImage.alt = "";
  generatedImage.style.display = "none";
}

function drawCard() {
  if (deck.length === 0 || hand.length >= handSize) {
    return;
  }
  hand.push(deck.shift());
}

function drawHand() {
  while (hand.length < handSize && deck.length > 0) {
    drawCard();
  }
}

function startLevel(index) {
  levelIndex = index;
  deck = buildDeck();
  hand = [];
  resetMask();
  resetGeneratedImage();
  playsLeft = levels[levelIndex].plays;
  status = "playing";
  drawHand();
  nextButton.disabled = true;
  message.textContent = "";
  render();
}

function getScore() {
  let score = 0;
  let filledSlots = 0;
  for (const key of Object.keys(mask)) {
    if (mask[key]) {
      score += mask[key].quality;
      filledSlots += 1;
    }
  }
  if (filledSlots === Object.keys(mask).length) {
    score += fullMaskBonus;
  }
  return score;
}

function getBonusText() {
  const filledSlots = Object.values(mask).filter(Boolean).length;
  if (filledSlots === Object.keys(mask).length) {
    return `Full mask bonus +${fullMaskBonus}`;
  }
  return "";
}

function isMaskComplete() {
  return Object.values(mask).every(Boolean);
}

function getMaskSignature() {
  return Object.keys(mask)
    .map((key) => (mask[key] ? mask[key].name : "Empty"))
    .join("|");
}

function buildImagePrompt() {
  const details = Object.keys(mask)
    .map((key) => `${slotLabels[key]}: ${mask[key].name}`)
    .join(", ");

  return [
    "A 3d pixel art old school video game render of a ceremonial mask.",
    `Features: ${details}.`,
    "Chunky pixels, voxel-like depth, vivid lighting, 3/4 view, dark backdrop.",
  ].join(" ");
}

function loadApiKey() {
  return OPENAI_API_KEY;
}

async function generateMaskImage() {
  if (!isMaskComplete()) {
    return;
  }

  const signature = getMaskSignature();
  if (signature === generatedImageSignature || isGeneratingImage) {
    return;
  }

  isGeneratingImage = true;
  imageStatus.textContent = "Generating pixel art...";

  try {
    const apiKey = await loadApiKey();
    const response = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-image-1",
        prompt: buildImagePrompt(),
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

    generatedImage.src = `data:image/png;base64,${base64Image}`;
    generatedImage.alt = "Generated mask art";
    generatedImage.style.display = "block";
    generatedImageSignature = signature;
    imageStatus.textContent = "Generated pixel art from your completed mask.";
  } catch (error) {
    console.error(error);
    imageStatus.textContent =
      "Could not generate art. Check env.sh access and your API key.";
  } finally {
    isGeneratingImage = false;
  }
}

function playCard(index) {
  if (status !== "playing") {
    return;
  }
  const card = hand[index];
  if (!card) {
    return;
  }

  mask[card.slot] = card;
  hand.splice(index, 1);
  drawCard();
  playsLeft -= 1;

  const score = getScore();
  const target = levels[levelIndex].target;

  if (score >= target) {
    status = "won";
    message.textContent = "Level cleared! Your mask is worthy.";
    nextButton.disabled = levelIndex >= levels.length - 1;
  } else if (playsLeft <= 0) {
    status = "lost";
    message.textContent = "Out of plays. Try a different design!";
  }

  render();
  generateMaskImage();
}

function renderMask() {
  maskGrid.innerHTML = "";
  for (const key of Object.keys(mask)) {
    const slot = document.createElement("div");
    slot.className = "mask-slot";

    const label = document.createElement("div");
    label.className = "slot-name";
    label.textContent = slotLabels[key];

    const name = document.createElement("div");
    name.className = "card-name";
    name.textContent = mask[key] ? mask[key].name : "Empty";

    const quality = document.createElement("div");
    quality.className = "card-quality";
    quality.textContent = mask[key]
      ? `Quality +${mask[key].quality}`
      : "Play a card to add a piece.";

    slot.append(label, name, quality);
    maskGrid.appendChild(slot);
  }
}

function renderHand() {
  handEl.innerHTML = "";
  hand.forEach((card, index) => {
    const cardEl = document.createElement("div");
    cardEl.className = "card";

    const title = document.createElement("h3");
    title.textContent = card.name;

    const slot = document.createElement("div");
    slot.className = "slot";
    slot.textContent = slotLabels[card.slot];

    const quality = document.createElement("div");
    quality.className = "quality";
    quality.textContent = `Quality +${card.quality}`;

    const text = document.createElement("div");
    text.textContent = card.text;

    const button = document.createElement("button");
    button.textContent = "Play Card";
    button.disabled = status !== "playing";
    button.addEventListener("click", () => playCard(index));

    cardEl.append(title, slot, quality, text, button);
    handEl.appendChild(cardEl);
  });
}

function render() {
  const level = levels[levelIndex];
  const score = getScore();

  levelLabel.textContent = `Level ${levelIndex + 1}`;
  targetLabel.textContent = `Target: ${level.target}`;
  scoreLabel.textContent = score;
  playsLabel.textContent = playsLeft;
  deckLabel.textContent = deck.length;
  handLabel.textContent = hand.length;
  bonusLabel.textContent = getBonusText();

  renderMask();
  renderHand();
}

resetButton.addEventListener("click", () => startLevel(levelIndex));
nextButton.addEventListener("click", () => {
  if (levelIndex < levels.length - 1) {
    startLevel(levelIndex + 1);
  }
});

startLevel(0);
