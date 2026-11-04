// Hero: a palavra VIVO!/MORTO! alterna, os bonecos (os mesmos do jogo) levantam e agacham,
// e a cada 3 comandos a tia faz o gesto ao contrário e uma criança erra.
import { drawAvatar, figureJoints, lerp, smooth } from './avatars.js';

const KIDS = [
  { name: 'Bia', color: '#FF8F6B', look: 'girl', cx: 0.13 },
  { name: 'Theo', color: '#36C9A6', look: 'boy', cx: 0.375 },
  { name: 'Lara', color: '#FFC845', look: 'girl', cx: 0.625 },
  { name: 'Davi', color: '#9BD3FF', look: 'boy', cx: 0.87 },
];
const STAND = { headY: -0.68, shoulderY: -0.58, hipY: -0.32, kneeW: 0.036, kneeY: -0.16, footW: 0.036, arm: [0.12, 0.05] };
const CROUCH = { headY: -0.40, shoulderY: -0.31, hipY: -0.15, kneeW: 0.078, kneeY: -0.115, footW: 0.052, arm: [0.6, 0.25] };

function spec(c, t, phase) {
  const e = smooth(c), sway = Math.sin(t * 2.2 + phase) * 0.006;
  const arm = [lerp(STAND.arm[0], CROUCH.arm[0], e), lerp(STAND.arm[1], CROUCH.arm[1], e)];
  return {
    headX: sway, headY: lerp(STAND.headY, CROUCH.headY, e), tilt: sway * 0.8,
    shoulderY: lerp(STAND.shoulderY, CROUCH.shoulderY, e), shoulderW: 0.071, shX: 0, hipX: 0,
    hipY: lerp(STAND.hipY, CROUCH.hipY, e), kneeW: lerp(STAND.kneeW, CROUCH.kneeW, e), kneeY: lerp(STAND.kneeY, CROUCH.kneeY, e),
    footW: lerp(STAND.footW, CROUCH.footW, e), footY: 0, armL: arm, armR: arm,
  };
}

const T = { pt: { v: 'VIVO!', m: 'MORTO!', up: 'de pé', down: 'agachado', err: 'errou!' } }.pt;

export function startHero() {
  const canvas = document.getElementById('kids');
  if (!canvas) return;
  const g = canvas.getContext('2d');
  const word = document.getElementById('heroWord'), screenWord = document.getElementById('screenWord');
  const screen = document.getElementById('screen');
  const armsUp = document.querySelector('#heroHost .arms-up'), armsDown = document.querySelector('#heroHost .arms-down');
  const stat = ['kB', 'kT', 'kL', 'kD'].map((id) => document.getElementById(id));
  const state = KIDS.map(() => ({ c: 0, target: 0 }));
  let vivo = true, step = 0, visible = true, last = performance.now(), t0 = last;
  let erred = false, running = false;

  function size() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(1, Math.round(canvas.clientWidth * dpr)), h = Math.max(1, Math.round(canvas.clientHeight * dpr));
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
  }
  function draw(now) {
    size();
    const W = canvas.width, H = canvas.height, aspect = W / H, t = (now - t0) / 1000;
    g.clearRect(0, 0, W, H);
    g.fillStyle = '#2A1E4F'; g.fillRect(0, 0, W, H);
    g.fillStyle = '#3F3160'; g.fillRect(0, H * 0.82, W, H * 0.18);
    KIDS.forEach((k, i) => {
      const f = { name: k.name, color: k.color, look: k.look, ready: !(i === 2 && erred), mood: '', plain: true,
                  joints: figureJoints({ cx: k.cx, floor: 0.93, k: 0.74 }, aspect, spec(state[i].c, t, i)), floor: 0.93 };
      drawAvatar(g, f, 0, 0, W, H);
    });
  }
  function tick() {
    step++; vivo = !vivo;
    const trick = step % 3 === 0;
    word.textContent = vivo ? T.v : T.m; word.classList.toggle('morto', !vivo);
    screenWord.textContent = vivo ? T.v : T.m; screen.classList.toggle('morto', !vivo);
    const gestureUp = trick ? !vivo : vivo;
    armsUp.style.display = gestureUp ? '' : 'none'; armsDown.style.display = gestureUp ? 'none' : '';
    state.forEach((s, i) => { s.target = (vivo ? 0 : 1); if (i === 2 && trick) s.target = vivo ? 1 : 0; });
    erred = trick;
    stat.forEach((el, i) => {
      const err = i === 2 && trick;
      el.textContent = err ? T.err : (vivo ? T.up : T.down);
      el.className = err ? 'err' : '';
    });
  }
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    state.forEach((s) => { s.c += Math.sign(s.target - s.c) * Math.min(Math.abs(s.target - s.c), dt * 3.2); });
    draw(now);
    if (running && visible && !document.hidden) requestAnimationFrame(frame);
  }
  // Começa rodando sempre (o movimento é pequeno e o botão permite pausar).
  const button = document.getElementById('heroToggle');
  let timer = null; running = true;
  function sync() {
    if (button) {
      button.textContent = running ? '⏸ Pausar animação' : '▶ Ver animação';
      button.setAttribute('aria-pressed', String(running));
    }
  }
  function play() {
    running = true; sync(); last = performance.now(); requestAnimationFrame(frame);
    if (!timer) timer = setInterval(() => { if (running && visible && !document.hidden) tick(); }, 1700);
  }
  function pause() { running = false; sync(); }
  button?.addEventListener('click', () => (running ? pause() : play()));
  new IntersectionObserver((e) => { visible = e[0].isIntersecting; if (visible && running) { last = performance.now(); requestAnimationFrame(frame); } }).observe(canvas);
  document.addEventListener('visibilitychange', () => { if (!document.hidden && visible && running) { last = performance.now(); requestAnimationFrame(frame); } });
  if (running) play(); else { sync(); draw(performance.now()); }
}
