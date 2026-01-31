const ui = {
  score: document.getElementById("score"),
  power: document.getElementById("power"),
  integrity: document.getElementById("integrity"),
  targetReadout: document.getElementById("target-readout"),
  outputReadout: document.getElementById("output-readout"),
  status: document.getElementById("status"),
  frequency: document.getElementById("frequency"),
  q: document.getElementById("q"),
  modulation: document.getElementById("modulation"),
  amp: document.getElementById("amp"),
  stability: document.getElementById("stability"),
  filter: document.getElementById("filter"),
  frequencyValue: document.getElementById("frequency-value"),
  qValue: document.getElementById("q-value"),
  modulationValue: document.getElementById("modulation-value"),
  ampValue: document.getElementById("amp-value"),
  stabilityValue: document.getElementById("stability-value"),
  fire: document.getElementById("fire"),
  overdrive: document.getElementById("overdrive"),
  retune: document.getElementById("retune"),
  buildings: [
    document.getElementById("building-1"),
    document.getElementById("building-2"),
    document.getElementById("building-3"),
    document.getElementById("building-4"),
  ],
};

const state = {
  score: 0,
  weaponPower: 0,
  integrity: 100,
  targets: [],
  destroyed: new Set(),
  overdriveReady: true,
};

const filterProfiles = {
  lowpass: { bias: -60, spread: 230, stabilityCost: 4 },
  bandpass: { bias: 0, spread: 140, stabilityCost: 6 },
  highpass: { bias: 80, spread: 180, stabilityCost: 5 },
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const randomBetween = (min, max) => Math.random() * (max - min) + min;

const formatHz = (value) => Math.round(value);

const updateReadouts = () => {
  ui.frequencyValue.textContent = ui.frequency.value;
  ui.qValue.textContent = ui.q.value;
  ui.modulationValue.textContent = `${ui.modulation.value}%`;
  ui.ampValue.textContent = `${ui.amp.value}%`;
  ui.stabilityValue.textContent = `${ui.stability.value}%`;
  ui.power.textContent = `${Math.round(state.weaponPower)}%`;
  ui.integrity.textContent = `${Math.round(state.integrity)}%`;
  ui.score.textContent = state.score;
};

const retuneTargets = () => {
  state.targets = ui.buildings.map(() =>
    randomBetween(140, 1080) + randomBetween(-60, 60)
  );
  state.destroyed.clear();
  ui.buildings.forEach((building) => {
    building.classList.remove("cracked", "shattered");
  });
  const targetAverage =
    state.targets.reduce((sum, value) => sum + value, 0) / state.targets.length;
  ui.targetReadout.textContent = formatHz(targetAverage);
  ui.status.textContent = "New resonance signatures acquired. Dial them in.";
};

const calculateOutput = () => {
  const frequency = Number(ui.frequency.value);
  const q = Number(ui.q.value);
  const modulation = Number(ui.modulation.value) / 100;
  const amp = Number(ui.amp.value) / 100;
  const stability = Number(ui.stability.value) / 100;
  const filter = filterProfiles[ui.filter.value];

  const modulationSpread = modulation * 180;
  const modulationOffset = (Math.sin(Date.now() / 400) * modulationSpread) / 2;
  const output = frequency + modulationOffset + filter.bias;

  const power =
    amp * 100 * (0.6 + q / 30) * (0.8 + modulation * 0.4) * stability;

  const stabilityDrain =
    filter.stabilityCost * (1 + modulation * 0.7 + amp * 0.4) * (q / 10);

  return {
    output,
    power: clamp(power, 0, 150),
    stabilityDrain: clamp(stabilityDrain, 0, 18),
    spread: filter.spread + modulationSpread + q * 4,
  };
};

const applyBlast = (isOverdrive) => {
  if (state.integrity <= 0) {
    ui.status.textContent = "Emitter offline. Retune to restart the siege.";
    return;
  }

  const { output, power, spread, stabilityDrain } = calculateOutput();
  const multiplier = isOverdrive ? 1.35 : 1;
  const tunedOutput = output * multiplier;
  const tunedSpread = spread * (isOverdrive ? 1.1 : 1);

  ui.outputReadout.textContent = formatHz(tunedOutput);
  state.weaponPower = clamp(power * multiplier, 0, 180);
  state.integrity = clamp(
    state.integrity - stabilityDrain * (isOverdrive ? 1.5 : 1),
    0,
    100
  );

  let hitCount = 0;
  let shatterCount = 0;

  state.targets.forEach((target, index) => {
    if (state.destroyed.has(index)) {
      return;
    }

    const delta = Math.abs(target - tunedOutput);
    if (delta < tunedSpread * 0.4) {
      ui.buildings[index].classList.add("shattered");
      state.destroyed.add(index);
      hitCount += 1;
      shatterCount += 1;
      state.score += Math.round(state.weaponPower * 2.2);
      return;
    }

    if (delta < tunedSpread) {
      ui.buildings[index].classList.add("cracked");
      hitCount += 1;
      state.score += Math.round(state.weaponPower * 0.6);
    }
  });

  if (shatterCount > 0) {
    ui.status.textContent = `Direct resonance! ${shatterCount} buildings shattered.`;
  } else if (hitCount > 0) {
    ui.status.textContent = "Close! Structures are cracking. Fine-tune more.";
  } else {
    ui.status.textContent = "No resonance lock. Adjust filters and try again.";
  }

  if (state.destroyed.size === ui.buildings.length) {
    ui.status.textContent =
      "Skyline collapsed. Retune for a fresh wave of targets.";
  }

  updateReadouts();
};

const updateLiveOutput = () => {
  const { output, power } = calculateOutput();
  ui.outputReadout.textContent = formatHz(output);
  state.weaponPower = power;
  updateReadouts();
};

const setupControls = () => {
  [
    ui.frequency,
    ui.q,
    ui.modulation,
    ui.amp,
    ui.stability,
    ui.filter,
  ].forEach((control) => {
    control.addEventListener("input", updateLiveOutput);
  });

  ui.fire.addEventListener("click", () => applyBlast(false));
  ui.overdrive.addEventListener("click", () => {
    if (!state.overdriveReady) {
      ui.status.textContent = "Overdrive cooling. Use normal pulse for now.";
      return;
    }
    state.overdriveReady = false;
    ui.status.textContent = "Overdrive pulse unleashed!";
    applyBlast(true);
    setTimeout(() => {
      state.overdriveReady = true;
      ui.status.textContent =
        "Overdrive ready. Push it to amplify the next blast.";
    }, 3500);
  });

  ui.retune.addEventListener("click", () => {
    state.integrity = 100;
    retuneTargets();
    updateReadouts();
  });
};

retuneTargets();
setupControls();
updateLiveOutput();
