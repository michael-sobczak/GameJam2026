// =====================
// TOP-DOWN HEIST GAME
// =====================

const canvas = document.createElement("canvas");
canvas.width = 640;
canvas.height = 480;
document.body.style.margin = "0";
document.body.appendChild(canvas);
canvas.focus();
const ctx = canvas.getContext("2d");

// ---- Constants ----
const TILE = 40;
const MASK_TIME = 10000;

// ---- Map ----
// 0 floor, 1 wall, 2 sculpture
const map = [
  [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  [1,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1],
  [1,0,1,1,1,0,1,1,1,1,0,1,1,0,0,1],
  [1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,1],
  [1,0,1,0,1,1,1,1,0,1,1,1,1,1,0,1],
  [1,0,1,0,0,0,0,1,0,0,0,0,0,1,0,1],
  [1,0,1,1,1,1,0,1,1,1,1,1,0,1,0,1],
  [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
  [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
];

// ---- Player ----
const player = {
  x: 1.5 * TILE,
  y: 1.5 * TILE,
  speed: 2,
  mask: null,
  maskStart: 0,
};

// ---- Guards ----
const guards = [
  {
    x: 8.5 * TILE,
    y: 1.5 * TILE,
    dir: 1,
    axis: "x",
    start: 8.5 * TILE,
    range: 4 * TILE,
    speed: 1,
    fov: Math.PI / 6,
    view: 120,
    alive: true,
  },
  {
    x: 4.5 * TILE,
    y: 6.5 * TILE,
    dir: 1,
    axis: "y",
    start: 6.5 * TILE,
    range: 3 * TILE,
    speed: 1,
    fov: Math.PI / 6,
    view: 120,
    alive: true,
  },
];

// ---- Masks ----
const masks = [
  { name: "Invisibility" },
  { name: "Walk Through Walls" },
  { name: "Defense" },
];

// ---- Input ----
const keys = {};
window.addEventListener("keydown", e => keys[e.key.toLowerCase()] = true);
window.addEventListener("keyup", e => keys[e.key.toLowerCase()] = false);

// ---- Helpers ----
function tileAt(x, y) {
  const tx = Math.floor(x / TILE);
  const ty = Math.floor(y / TILE);
  return map[ty]?.[tx] ?? 1;
}

// ---- Game Logic ----
function update() {
  let nx = player.x;
  let ny = player.y;

  if (keys["w"]) ny -= player.speed;
  if (keys["s"]) ny += player.speed;
  if (keys["a"]) nx -= player.speed;
  if (keys["d"]) nx += player.speed;

  if (
    tileAt(nx, player.y) === 0 ||
    player.mask?.name === "Walk Through Walls"
  ) player.x = nx;

  if (
    tileAt(player.x, ny) === 0 ||
    player.mask?.name === "Walk Through Walls"
  ) player.y = ny;

  // Use mask
  if (keys["e"] && masks.length && !player.mask) {
    player.mask = masks.shift();
    player.maskStart = performance.now();
    keys["e"] = false;
  }

  // Mask expiry
  if (player.mask && performance.now() - player.maskStart > MASK_TIME) {
    player.mask = null;
  }

  // Guards
  guards.forEach(g => {
    if (!g.alive) return;

    if (g.axis === "x") g.x += g.speed * g.dir;
    else g.y += g.speed * g.dir;

    if (Math.abs((g.axis === "x" ? g.x : g.y) - g.start) > g.range) {
      g.dir *= -1;
    }

    if (player.mask?.name === "Invisibility") return;

    // Vision check
    const dx = player.x - g.x;
    const dy = player.y - g.y;
    const dist = Math.hypot(dx, dy);
    if (dist > g.view) return;

    const facing = g.axis === "x"
      ? (g.dir === 1 ? 0 : Math.PI)
      : (g.dir === 1 ? Math.PI / 2 : -Math.PI / 2);

    const angle = Math.atan2(dy, dx);
    const diff = Math.abs(angle - facing);

    if (diff < g.fov) {
      alert("Guard caught you 🚨");
      location.reload();
    }
  });

  // Win
  if (tileAt(player.x, player.y) === 2) {
    alert("You stole the sculpture 🗿💎");
    location.reload();
  }
}

// ---- Render ----
function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Map
  map.forEach((row, y) =>
    row.forEach((t, x) => {
      if (t === 1) ctx.fillStyle = "#444";
      else if (t === 2) ctx.fillStyle = "lime";
      else return;
      ctx.fillRect(x * TILE, y * TILE, TILE, TILE);
    })
  );

  // Guards
  guards.forEach(g => {
    if (!g.alive) return;
    ctx.fillStyle = "red";
    ctx.fillRect(g.x - 10, g.y - 10, 20, 20);

    // vision cone
    ctx.fillStyle = "rgba(255,0,0,0.2)";
    ctx.beginPath();
    ctx.moveTo(g.x, g.y);
    const base =
      g.axis === "x"
        ? (g.dir === 1 ? 0 : Math.PI)
        : (g.dir === 1 ? Math.PI / 2 : -Math.PI / 2);
    ctx.arc(g.x, g.y, g.view, base - g.fov, base + g.fov);
    ctx.fill();
  });

  // Player
  ctx.fillStyle = "dodgerblue";
  ctx.fillRect(player.x - 10, player.y - 10, 20, 20);

  // HUD
  ctx.fillStyle = "#fff";
  ctx.font = "14px monospace";
  ctx.fillText(
    "Mask: " + (player.mask ? player.mask.name : "None"),
    10,
    20
  );
}

// ---- Loop ----
function loop() {
  update();
  draw();
  requestAnimationFrame(loop);
}

loop();
