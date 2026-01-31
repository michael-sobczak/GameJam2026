const playArea = document.querySelector("#play-area");
const pieces = Array.from(document.querySelectorAll(".piece"));
const slots = Array.from(document.querySelectorAll(".slot"));
const status = document.querySelector("#status");
const resetButton = document.querySelector("#reset");

let activePiece = null;
let offsetX = 0;
let offsetY = 0;

const isInside = (point, rect) =>
  point.x >= rect.left &&
  point.x <= rect.right &&
  point.y >= rect.top &&
  point.y <= rect.bottom;

const storeHomes = () => {
  const playRect = playArea.getBoundingClientRect();
  pieces.forEach((piece) => {
    const rect = piece.getBoundingClientRect();
    piece.dataset.homeX = rect.left - playRect.left;
    piece.dataset.homeY = rect.top - playRect.top;
  });
};

const movePieceTo = (piece, x, y) => {
  piece.style.left = `${x}px`;
  piece.style.top = `${y}px`;
};

const snapPieceToSlot = (piece, slot) => {
  const playRect = playArea.getBoundingClientRect();
  const slotRect = slot.getBoundingClientRect();
  const centerX = slotRect.left - playRect.left + slotRect.width / 2;
  const centerY = slotRect.top - playRect.top + slotRect.height / 2;
  movePieceTo(piece, centerX, centerY);
};

const clearSlot = (piece) => {
  const filledSlot = slots.find((slot) => slot.dataset.filled === piece.dataset.piece);
  if (filledSlot) {
    delete filledSlot.dataset.filled;
    filledSlot.classList.remove("filled");
  }
};

const updateStatus = () => {
  const placed = slots.filter((slot) => slot.dataset.filled).length;
  status.textContent = `Pieces placed: ${placed} / ${slots.length}`;
  if (placed === slots.length) {
    status.textContent = "Theme complete! The Eclipse Festival mask is whole.";
  }
};

const resetPieces = () => {
  pieces.forEach((piece) => {
    piece.dataset.locked = "false";
    piece.classList.remove("placed");
    movePieceTo(piece, Number(piece.dataset.homeX), Number(piece.dataset.homeY));
  });
  slots.forEach((slot) => {
    delete slot.dataset.filled;
    slot.classList.remove("filled");
  });
  updateStatus();
};

const findMatchingSlot = (piece) => {
  const pieceRect = piece.getBoundingClientRect();
  const center = {
    x: pieceRect.left + pieceRect.width / 2,
    y: pieceRect.top + pieceRect.height / 2,
  };
  return slots.find((slot) => {
    const slotRect = slot.getBoundingClientRect();
    return isInside(center, slotRect) && slot.dataset.accept === piece.dataset.piece;
  });
};

const onPointerDown = (event) => {
  const piece = event.currentTarget;
  if (piece.dataset.locked === "true") {
    return;
  }
  activePiece = piece;
  activePiece.classList.add("dragging");
  activePiece.setPointerCapture(event.pointerId);
  const pieceRect = activePiece.getBoundingClientRect();
  offsetX = event.clientX - pieceRect.left;
  offsetY = event.clientY - pieceRect.top;
  clearSlot(activePiece);
};

const onPointerMove = (event) => {
  if (!activePiece) {
    return;
  }
  const playRect = playArea.getBoundingClientRect();
  const x = event.clientX - playRect.left - offsetX + activePiece.offsetWidth / 2;
  const y = event.clientY - playRect.top - offsetY + activePiece.offsetHeight / 2;
  movePieceTo(activePiece, x, y);
};

const onPointerUp = (event) => {
  if (!activePiece) {
    return;
  }
  activePiece.releasePointerCapture(event.pointerId);
  activePiece.classList.remove("dragging");

  const match = findMatchingSlot(activePiece);
  if (match && !match.dataset.filled) {
    snapPieceToSlot(activePiece, match);
    match.dataset.filled = activePiece.dataset.piece;
    match.classList.add("filled");
    activePiece.dataset.locked = "true";
    activePiece.classList.add("placed");
  } else {
    movePieceTo(
      activePiece,
      Number(activePiece.dataset.homeX),
      Number(activePiece.dataset.homeY),
    );
  }

  activePiece = null;
  updateStatus();
};

pieces.forEach((piece) => {
  piece.addEventListener("pointerdown", onPointerDown);
  piece.addEventListener("pointermove", onPointerMove);
  piece.addEventListener("pointerup", onPointerUp);
});

resetButton.addEventListener("click", resetPieces);
window.addEventListener("resize", () => {
  storeHomes();
  resetPieces();
});

storeHomes();
updateStatus();
