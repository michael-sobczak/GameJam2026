// =========================
// 2.5D HEIST GAME (FIXED)
// =========================

// ---- Canvas ----
const canvas = document.createElement("canvas");
canvas.width = 800;
canvas.height = 450;
canvas.tabIndex = 1; // allow keyboard focus
document.body.style.margin = "0";
document.body.style.background = "#000";
document.body.appendChild(canvas);
canvas.focus();

const ctx = canvas.getContext("2d");

// Prevent arrow keys from scrolling page
window.addEventListener("keydown", e => {
  if (["ArrowLeft", "ArrowRight"].includes(e.key)) {
    e.preventDefault();
  }
});

// ---- Constants ----
const FOV = Math.PI / 3;
const RAYS = 240;
const MAX_DIST = 20;
const MASK_DURATION = 10000;

// ---- Map ----
const map = [
  [1,1,1,1,1,1,1,1],
  [1,0,0,0,0,0,0,1],
  [1,0,1,1,0,0,0,1],
  [1,0,0,0,0,1,0,1],
  [1,0,0,0,4,0,0,1],
  [1,1,1,1,1,1,1,1],
];

// ---- Player ----
const player = {
  x: 2.5,
  y: 2.5,
  angle: 0,
  speed: 0.06,
  inventory: [],
  activeMask: null,
  maskTimer: 0,
};

// ---- Guards ----
const guards = [
  {
    x: 5.5,
    y: 1.5,
    angle: Math.PI,
    dir: 1,
    startX: 5.5,
    patrol: 1.5,
    speed: 0.02,
    fov: Math.PI / 8,
    range: 4,
    alive: true
  },
  {
    x: 2.5,
    y: 4.5,
    angle: 0,
    dir: 1,
    startX: 2.5,
    patrol: 1.5,
    speed: 0.02,
    fov: Math.PI / 8,
    range: 4,
    alive: true
  }
];

// ---- Masks ----
const MASKS = {
  INVIS: { name: "Invisibility" },
  PHASE: { name: "Walk Through Walls" },
  SHOOT: {
    name: "Shoot Guard",
    use: () => {
      guards.forEach(g => {
        if (!g.alive) return;
        const dx = g.x - player.x;
        const dy = g.y - player.y;
        const dist = Math.hypot(dx, dy);
        const ang = Math.atan2(dy, dx);
        if (dist < 4 && Math.abs(ang - player.angle) < 0.2) {
          g.alive = false;
        }
      });
    }
  }
};

player.inventory = [MASKS.INVIS, MASKS.PHASE, MASKS.SHOOT];

// ---- Input ----
const keys = {};
window.addEventListener("keydown", e => keys[e.key.toLowerCase()] = true);
window.addEventListener("keyup", e => keys[e.key.toLowerCase()] = false);

// ---- Helpers ----
function mapAt(x, y) {
  if (y < 0 || y >= map.length || x < 0 || x >= map[0].length) return 1;
  return map[y][x];
}

function activateMask(mask) {
  if (player.activeMask) return;
  player.activeMask = mask;
  player.maskTimer = performance.now();
  if (mask.use) mask.use();
}

// ---- Guards ----
function updateGuards() {
  guards.forEach(g => {
    if (!g.alive) return;

    g.x += g.speed * g.dir;
    if (Math.abs(g.x - g.startX) > g.patrol) {
      g.dir *= -1;
      g.angle += Math.PI;
    }

    if (player.activeMask === MASKS.INVIS) return;

    const dx = player.x - g.x;
    const dy = player.y - g.y;
    const dist = Math.hypot(dx, dy);
    if (dist > g.range) return;

    const angleToPlayer = Math.atan2(dy, dx);
    const diff = Math.abs(angleToPlayer - g.angle);

    if (diff < g.fov) {
      // line of sight
      for (let d = 0; d < dist; d += 0.1) {
        const tx = Math.floor(g.x + Math.cos(angleToPlayer) * d);
        const ty = Math.floor(g.y + Math.sin(angleToPlayer) * d);
        if (mapAt(tx, ty) === 1) return;
      }
      alert("You were spotted 🚨");
      location.reload();
    }
  });
}

// ---- Game Update ----
function update() {
  if (keys["arrowleft"]) player.angle -= 0.04;
  if (keys["arrowright"]) player.angle += 0.04;

  let nx = player.x;
  let ny = player.y;

  if (keys["w"]) {
    nx += Math.cos(player.angle) * player.speed;
    ny += Math.sin(player.angle) * player.speed;
  }
  if (keys["s"]) {
    nx -= Math.cos(player.angle) * player.speed;
    ny -= Math.sin(player.angle) * player.speed;
  }

  const tile = mapAt(Math.floor(nx), Math.floor(ny));
  if (tile === 0 || player.activeMask === MASKS.PHASE) {
    player.x = nx;
    player.y = ny;
  }

  if (keys["e"] && player.inventory.length) {
    activateMask(player.inventory.shift());
    keys["e"] = false;
  }

  if (player.activeMask && performance.now() - player.maskTimer > MASK_DURATION) {
    player.activeMask = null;
  }

  updateGuards();

  if (mapAt(Math.floor(player.x), Math.floor(player.y)) === 4) {
    alert("You stole the sculpture 🗿💎");
    location.reload();
  }
}

// ---- Render ----
function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Walls
  for (let i = 0; i < RAYS; i++) {
    const rayAngle = player.angle - FOV / 2 + (i / RAYS) * FOV;
    let dist = 0;

    while (dist < MAX_DIST) {
      const rx = player.x + Math.cos(rayAngle) * dist;
      const ry = player.y + Math.sin(rayAngle) * dist;
      const tile = mapAt(Math.floor(rx), Math.floor(ry));

      if (tile !== 0) {
        const h = canvas.height / (dist + 0.0001);
        ctx.fillStyle = tile === 4 ? "#0f0" : "#777";
        ctx.fillRect(
          (i / RAYS) * canvas.width,
          canvas.height / 2 - h / 2,
          canvas.width / RAYS + 1,
          h
        );
        break;
      }
      dist += 0.05;
    }
  }

  // Guards as red squares (billboards)
  guards.forEach(g => {
    if (!g.alive) return;
    const dx = g.x - player.x;
    const dy = g.y - player.y;
    const dist = Math.hypot(dx, dy);
    const angle = Math.atan2(dy, dx) - player.angle;

    if (Math.abs(angle) < FOV / 2) {
      const screenX = (0.5 + angle / FOV) * canvas.width;
      const size = canvas.height / (dist + 0.1);
      ctx.fillStyle = "red";
      ctx.fillRect(
        screenX - size / 4,
        canvas.height / 2 - size / 2,
        size / 2,
        size
      );
    }
  });

  // HUD
  ctx.fillStyle = "#fff";
  ctx.font = "14px monospace";
  ctx.fillText(
    "Mask: " + (player.activeMask ? player.activeMask.name : "None"),
    10, 20
  );
}

// ---- Loop ----
function loop() {
  update();
  render();
  requestAnimationFrame(loop);
}

loop();
