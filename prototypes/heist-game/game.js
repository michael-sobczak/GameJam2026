const canvas = document.getElementById("gameCanvas");
const ctx = canvas.getContext("2d");

const levelLabel = document.getElementById("levelLabel");
const manaLabel = document.getElementById("manaLabel");
const maskLabel = document.getElementById("maskLabel");
const manaFill = document.getElementById("manaFill");
const overlay = document.getElementById("overlay");
const overlayTitle = document.getElementById("overlayTitle");
const overlayText = document.getElementById("overlayText");
const restartButton = document.getElementById("restartButton");
const nextButton = document.getElementById("nextButton");

const assetPaths = {
  floor: "assets/floor.png",
  wall: "assets/wall.png",
  player: "assets/player.png",
  guard: "assets/guard.png",
  treasure: "assets/treasure.png",
};
const assets = {};
let assetsReady = false;

const tileSize = 40;
const playerRadius = 14;
const baseSpeed = 120;
const guardSpeed = 70;

const masks = {
  police: { name: "Police Disguise", drain: 10 },
  wall: { name: "Wall Vision", drain: 12 },
  speed: { name: "Speed Burst", cost: 20, duration: 2.2, multiplier: 2.4 },
};

const levels = [
  {
    name: "Museum Lobby",
    mana: 60,
    map: [
      "########################",
      "#S.....#...........T...#",
      "#......#...............#",
      "#......#..#######......#",
      "#......#...............#",
      "#......############....#",
      "#......................#",
      "#....#......#..........#",
      "#....#......#..........#",
      "#....######.#..####....#",
      "#..........#...........#",
      "#..####....#....#####..#",
      "#.................#....#",
      "#.................#....#",
      "########################",
    ],
    guards: [
      {
        path: [
          { x: 8, y: 6 },
          { x: 18, y: 6 },
        ],
        speed: guardSpeed,
      },
      {
        path: [
          { x: 5, y: 10 },
          { x: 5, y: 3 },
        ],
        speed: guardSpeed * 0.9,
      },
    ],
  },
  {
    name: "Vault Halls",
    mana: 75,
    map: [
      "########################",
      "#S..#..............#..T#",
      "#...#..######..#...#...#",
      "#...#.......#..#.......#",
      "#...######..#..####....#",
      "#.........#.#.......#..#",
      "#..#....#.#..#####.#...#",
      "#....#....#.#..#....#..#",
      "#....####.#.####.##....#",
      "#........#......#...#..#",
      "#..####..########..#...#",
      "#..#................#..#",
      "#..#..############..#..#",
      "#.................#....#",
      "########################",
    ],
    guards: [
      {
        path: [
          { x: 6, y: 7 },
          { x: 6, y: 12 },
        ],
        speed: guardSpeed * 1.05,
      },
      {
        path: [
          { x: 14, y: 3 },
          { x: 20, y: 3 },
        ],
        speed: guardSpeed * 0.95,
      },
      {
        path: [
          { x: 18, y: 10 },
          { x: 10, y: 10 },
        ],
        speed: guardSpeed,
      },
    ],
  },
  {
    name: "Grand Gallery",
    mana: 90,
    map: [
      "########################",
      "#S.....#...............#",
      "#.###..#..###########...#",
      "#...#..#..#.........#..#",
      "###.#..#..#..#####..#..#",
      "#...#.....#..#...#..#..#",
      "#..#######..#...#..#...#",
      "#..........#...#..#..T.#",
      "#..#######..#...#..#####",
      "#...#.......#...#......#",
      "#...#..##############..#",
      "#...#...............#..#",
      "#...##############..#..#",
      "#..................#...#",
      "########################",
    ],
    guards: [
      {
        path: [
          { x: 6, y: 7 },
          { x: 16, y: 7 },
        ],
        speed: guardSpeed * 1.1,
      },
      {
        path: [
          { x: 17, y: 12 },
          { x: 20, y: 12 },
        ],
        speed: guardSpeed,
      },
      {
        path: [
          { x: 8, y: 3 },
          { x: 8, y: 9 },
        ],
        speed: guardSpeed * 0.9,
      },
      {
        path: [
          { x: 12, y: 5 },
          { x: 18, y: 5 },
        ],
        speed: guardSpeed * 1.05,
      },
    ],
  },
];

let levelIndex = 0;
let grid = [];
let mapWidth = 0;
let mapHeight = 0;
let player = null;
let treasure = null;
let guards = [];
let mana = 0;
let maxMana = 0;
let activeMask = null;
let speedBurst = { active: false, timeLeft: 0 };
let status = "playing";

const keys = new Set();
let lastTime = performance.now();

async function loadAssets() {
  const entries = Object.entries(assetPaths);
  await Promise.all(
    entries.map(async ([key, src]) => {
      const image = new Image();
      image.src = src;
      await new Promise((resolve, reject) => {
        image.onload = resolve;
        image.onerror = reject;
      });
      assets[key] = image;
    }),
  );
  assetsReady = true;
}

function parseLevel(level) {
  const parsedGrid = level.map.map((row) => row.split(""));
  let start = null;
  let goal = null;

  for (let y = 0; y < parsedGrid.length; y += 1) {
    for (let x = 0; x < parsedGrid[y].length; x += 1) {
      if (parsedGrid[y][x] === "S") {
        start = { x, y };
        parsedGrid[y][x] = ".";
      }
      if (parsedGrid[y][x] === "T") {
        goal = { x, y };
        parsedGrid[y][x] = ".";
      }
    }
  }

  return { grid: parsedGrid, start, treasure: goal };
}

function loadLevel(index) {
  const level = levels[index];
  const parsed = parseLevel(level);
  grid = parsed.grid;
  mapWidth = Math.max(...grid.map((row) => row.length));
  mapHeight = grid.length;
  canvas.width = mapWidth * tileSize;
  canvas.height = mapHeight * tileSize;
  treasure = parsed.treasure;
  player = {
    x: (parsed.start.x + 0.5) * tileSize,
    y: (parsed.start.y + 0.5) * tileSize,
    radius: playerRadius,
  };
  guards = level.guards.map((guard) => ({
    x: (guard.path[0].x + 0.5) * tileSize,
    y: (guard.path[0].y + 0.5) * tileSize,
    path: guard.path.map((point) => ({
      x: (point.x + 0.5) * tileSize,
      y: (point.y + 0.5) * tileSize,
    })),
    pathIndex: 1,
    speed: guard.speed,
    dir: { x: 1, y: 0 },
    visionDistance: 190,
    visionAngle: Math.PI / 2.3,
  }));
  mana = level.mana;
  maxMana = level.mana;
  activeMask = null;
  speedBurst = { active: false, timeLeft: 0 };
  status = "playing";
  hideOverlay();
  updateUI();
}

function isWallTile(tileX, tileY) {
  if (tileY < 0 || tileY >= mapHeight || tileX < 0 || tileX >= mapWidth) {
    return true;
  }
  if (tileX >= grid[tileY].length) {
    return true;
  }
  return grid[tileY][tileX] === "#";
}

function isWallAt(x, y) {
  const tileX = Math.floor(x / tileSize);
  const tileY = Math.floor(y / tileSize);
  return isWallTile(tileX, tileY);
}

function lineOfSight(start, end) {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const distance = Math.hypot(dx, dy);
  if (distance < 1) {
    return true;
  }
  const steps = Math.ceil(distance / 6);
  const stepX = dx / steps;
  const stepY = dy / steps;
  let x = start.x;
  let y = start.y;
  for (let i = 0; i < steps; i += 1) {
    if (isWallAt(x, y)) {
      return false;
    }
    x += stepX;
    y += stepY;
  }
  return true;
}

function movePlayer(dt) {
  let inputX = 0;
  let inputY = 0;
  if (keys.has("ArrowUp") || keys.has("w")) inputY -= 1;
  if (keys.has("ArrowDown") || keys.has("s")) inputY += 1;
  if (keys.has("ArrowLeft") || keys.has("a")) inputX -= 1;
  if (keys.has("ArrowRight") || keys.has("d")) inputX += 1;

  if (inputX === 0 && inputY === 0) {
    return;
  }

  const length = Math.hypot(inputX, inputY);
  const normalizedX = inputX / length;
  const normalizedY = inputY / length;
  const speedMultiplier = speedBurst.active ? masks.speed.multiplier : 1;
  const speed = baseSpeed * speedMultiplier;
  const dx = normalizedX * speed * dt;
  const dy = normalizedY * speed * dt;

  attemptMove(dx, 0);
  attemptMove(0, dy);
}

function attemptMove(dx, dy) {
  const nextX = player.x + dx;
  const nextY = player.y + dy;

  const left = nextX - player.radius;
  const right = nextX + player.radius;
  const top = nextY - player.radius;
  const bottom = nextY + player.radius;

  if (
    !isWallAt(left, top) &&
    !isWallAt(right, top) &&
    !isWallAt(left, bottom) &&
    !isWallAt(right, bottom)
  ) {
    player.x = nextX;
    player.y = nextY;
  }
}

function updateGuards(dt) {
  guards.forEach((guard) => {
    const target = guard.path[guard.pathIndex];
    const dx = target.x - guard.x;
    const dy = target.y - guard.y;
    const distance = Math.hypot(dx, dy);
    if (distance < 2) {
      guard.pathIndex = (guard.pathIndex + 1) % guard.path.length;
      return;
    }
    const dirX = dx / distance;
    const dirY = dy / distance;
    guard.dir = { x: dirX, y: dirY };
    guard.x += dirX * guard.speed * dt;
    guard.y += dirY * guard.speed * dt;
  });
}

function updateMasks(dt) {
  if (activeMask === "police" || activeMask === "wall") {
    const drain = masks[activeMask].drain * dt;
    mana = Math.max(0, mana - drain);
    if (mana === 0) {
      activeMask = null;
    }
  }

  if (speedBurst.active) {
    speedBurst.timeLeft -= dt;
    if (speedBurst.timeLeft <= 0) {
      speedBurst.active = false;
      speedBurst.timeLeft = 0;
    }
  }
}

function guardSeesPlayer(guard) {
  const toPlayerX = player.x - guard.x;
  const toPlayerY = player.y - guard.y;
  const distance = Math.hypot(toPlayerX, toPlayerY);
  if (distance > guard.visionDistance) {
    return false;
  }

  const dir = guard.dir;
  const normX = toPlayerX / distance;
  const normY = toPlayerY / distance;
  const dot = dir.x * normX + dir.y * normY;
  const angle = Math.acos(Math.max(-1, Math.min(1, dot)));
  if (angle > guard.visionAngle * 0.5) {
    return false;
  }

  if (!lineOfSight({ x: guard.x, y: guard.y }, { x: player.x, y: player.y })) {
    return false;
  }

  if (activeMask === "police") {
    return distance < 28;
  }

  return true;
}

function checkDetection() {
  if (status !== "playing") {
    return;
  }
  for (const guard of guards) {
    if (guardSeesPlayer(guard)) {
      status = "caught";
      showOverlay("Caught!", "Guards spotted you. Try a different mask.");
      break;
    }
  }
}

function checkWin() {
  if (status !== "playing") {
    return;
  }
  const treasurePos = {
    x: (treasure.x + 0.5) * tileSize,
    y: (treasure.y + 0.5) * tileSize,
  };
  const distance = Math.hypot(player.x - treasurePos.x, player.y - treasurePos.y);
  if (distance < player.radius + 10) {
    status = "won";
    showOverlay("Treasure Secured!", "You escaped with the loot.");
  }
}

function showOverlay(title, text) {
  overlayTitle.textContent = title;
  overlayText.textContent = text;
  overlay.classList.add("active");
  nextButton.style.display = status === "won" && levelIndex < levels.length - 1 ? "inline-flex" : "none";
}

function hideOverlay() {
  overlay.classList.remove("active");
}

function updateUI() {
  levelLabel.textContent = `${levelIndex + 1} · ${levels[levelIndex].name}`;
  manaLabel.textContent = `${Math.ceil(mana)} / ${maxMana}`;
  const maskName = activeMask ? masks[activeMask].name : speedBurst.active ? masks.speed.name : "None";
  maskLabel.textContent = maskName;
  manaFill.style.width = `${(mana / maxMana) * 100}%`;
}

function setActiveMask(maskId) {
  if (status !== "playing") {
    return;
  }
  if (maskId === "speed") {
    if (mana >= masks.speed.cost && !speedBurst.active) {
      mana -= masks.speed.cost;
      speedBurst.active = true;
      speedBurst.timeLeft = masks.speed.duration;
    }
    updateUI();
    return;
  }
  activeMask = activeMask === maskId ? null : maskId;
  updateUI();
}

function castRay(origin, angle, maxDistance, ignoreWalls) {
  const step = 6;
  let distance = 0;
  let x = origin.x;
  let y = origin.y;

  while (distance < maxDistance) {
    const nextX = x + Math.cos(angle) * step;
    const nextY = y + Math.sin(angle) * step;
    if (!ignoreWalls && isWallAt(nextX, nextY)) {
      return { x, y };
    }
    x = nextX;
    y = nextY;
    distance += step;
  }
  return { x, y };
}

function buildVisionPolygon(guard, ignoreWalls) {
  const points = [{ x: guard.x, y: guard.y }];
  const baseAngle = Math.atan2(guard.dir.y, guard.dir.x);
  const segments = 20;
  const startAngle = baseAngle - guard.visionAngle / 2;
  const endAngle = baseAngle + guard.visionAngle / 2;

  for (let i = 0; i <= segments; i += 1) {
    const angle = startAngle + (i / segments) * (endAngle - startAngle);
    points.push(castRay({ x: guard.x, y: guard.y }, angle, guard.visionDistance, ignoreWalls));
  }
  return points;
}

function drawVisionCone(guard, ignoreWalls, alpha) {
  const points = buildVisionPolygon(guard, ignoreWalls);
  ctx.beginPath();
  points.forEach((point, index) => {
    if (index === 0) {
      ctx.moveTo(point.x, point.y);
    } else {
      ctx.lineTo(point.x, point.y);
    }
  });
  ctx.closePath();
  ctx.fillStyle = `rgba(255, 120, 120, ${alpha})`;
  ctx.fill();
}

function drawSprite(image, x, y, size) {
  if (!image) {
    return false;
  }
  ctx.drawImage(image, x - size / 2, y - size / 2, size, size);
  return true;
}

function drawGrid() {
  ctx.fillStyle = "#0f1324";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.imageSmoothingEnabled = false;

  for (let y = 0; y < mapHeight; y += 1) {
    for (let x = 0; x < mapWidth; x += 1) {
      const tile = grid[y]?.[x];
      const isWall = tile !== ".";
      if (assetsReady && isWall && assets.wall) {
        ctx.drawImage(assets.wall, x * tileSize, y * tileSize, tileSize, tileSize);
      } else if (assetsReady && !isWall && assets.floor) {
        ctx.drawImage(assets.floor, x * tileSize, y * tileSize, tileSize, tileSize);
      } else if (isWall) {
        ctx.fillStyle = "#3b435a";
        ctx.fillRect(x * tileSize, y * tileSize, tileSize, tileSize);
        ctx.fillStyle = "#2b3246";
        ctx.fillRect(x * tileSize + 3, y * tileSize + 3, tileSize - 6, tileSize - 6);
      } else {
        ctx.fillStyle = "#1b2033";
        ctx.fillRect(x * tileSize, y * tileSize, tileSize, tileSize);
      }
    }
  }
}

function drawTreasure(canSeeThroughWalls) {
  const treasurePos = {
    x: (treasure.x + 0.5) * tileSize,
    y: (treasure.y + 0.5) * tileSize,
  };
  const visible = canSeeThroughWalls || lineOfSight({ x: player.x, y: player.y }, treasurePos);
  if (!visible) {
    return;
  }
  const size = tileSize * 0.6;
  if (!drawSprite(assets.treasure, treasurePos.x, treasurePos.y, size)) {
    ctx.fillStyle = "#ffd27a";
    ctx.beginPath();
    ctx.arc(treasurePos.x, treasurePos.y, 12, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawGuards(canSeeThroughWalls) {
  guards.forEach((guard) => {
    const visible = canSeeThroughWalls || lineOfSight({ x: player.x, y: player.y }, guard);
    if (!visible) {
      return;
    }
    const size = tileSize * 0.7;
    if (!drawSprite(assets.guard, guard.x, guard.y, size)) {
      ctx.fillStyle = "#ff8888";
      ctx.beginPath();
      ctx.arc(guard.x, guard.y, 12, 0, Math.PI * 2);
      ctx.fill();
    }
  });
}

function drawPlayer() {
  const size = tileSize * 0.7;
  if (!drawSprite(assets.player, player.x, player.y, size)) {
    ctx.fillStyle = "#6ee7ff";
    ctx.beginPath();
    ctx.arc(player.x, player.y, player.radius, 0, Math.PI * 2);
    ctx.fill();
  }

  if (activeMask) {
    ctx.strokeStyle = activeMask === "police" ? "#7cf59d" : "#7aa7ff";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(player.x, player.y, player.radius + 4, 0, Math.PI * 2);
    ctx.stroke();
  }
}

function render() {
  const canSeeThroughWalls = activeMask === "wall";

  drawGrid();

  guards.forEach((guard) => {
    if (canSeeThroughWalls) {
      drawVisionCone(guard, true, 0.15);
    } else if (lineOfSight({ x: player.x, y: player.y }, guard)) {
      drawVisionCone(guard, false, 0.08);
    }
  });

  drawTreasure(canSeeThroughWalls);
  drawGuards(canSeeThroughWalls);
  drawPlayer();
}

function update(dt) {
  if (status === "playing") {
    movePlayer(dt);
    updateGuards(dt);
    updateMasks(dt);
    checkDetection();
    checkWin();
    updateUI();
  }
  render();
}

function gameLoop(now) {
  const dt = Math.min(0.05, (now - lastTime) / 1000);
  lastTime = now;
  update(dt);
  requestAnimationFrame(gameLoop);
}

window.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();
  if (["arrowup", "arrowdown", "arrowleft", "arrowright", " "].includes(event.key)) {
    event.preventDefault();
  }
  keys.add(key);
  if (key === "1") setActiveMask("police");
  if (key === "2") setActiveMask("wall");
  if (key === "3") setActiveMask("speed");
});

window.addEventListener("keyup", (event) => {
  keys.delete(event.key.toLowerCase());
});

restartButton.addEventListener("click", () => {
  loadLevel(levelIndex);
});

nextButton.addEventListener("click", () => {
  if (levelIndex < levels.length - 1) {
    levelIndex += 1;
    loadLevel(levelIndex);
  }
});

loadAssets()
  .catch((error) => {
    console.error("Asset load failed, using fallback shapes.", error);
  })
  .finally(() => {
    loadLevel(0);
    requestAnimationFrame(gameLoop);
  });
