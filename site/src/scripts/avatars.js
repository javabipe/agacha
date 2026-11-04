// Desenho dos avatares do Agacha!, portado da página da TV do app (Packages/AganhaTV/TVPage.swift).
// As juntas vêm de código; nenhuma imagem de criança é usada.
/* eslint-disable */
var animT = 0;
// ---------- avatares (desenhados a partir das juntas do corpo, nunca da imagem)
var SKIN = '#FFD9B8', SKIN_EDGE = '#B97F5C', INK = '#2B2140', blinking = false;
function clamp(v, lo, hi){ return Math.max(lo, Math.min(hi, v)); }
function shade(hex, f){
  var n = parseInt(hex.replace('#', ''), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return 'rgb(' + clamp(Math.round(r * f), 0, 255) + ',' + clamp(Math.round(g * f), 0, 255) + ',' + clamp(Math.round(b * f), 0, 255) + ')';
}
// Mistura com branco (t de 0 a 1) para o brilho.
function tint(hex, t){
  var n = parseInt(hex.replace('#', ''), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return 'rgb(' + Math.round(r + (255 - r) * t) + ',' + Math.round(g + (255 - g) * t) + ',' + Math.round(b + (255 - b) * t) + ')';
}
function mid(a, b){ return (a && b) ? [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2] : (a || b); }
function dot(g, p, r, color){ if (!p) return; g.fillStyle = color; g.beginPath(); g.arc(p[0], p[1], r, 0, 6.2832); g.fill(); }
// Membro de um ou mais segmentos (juntas que faltam são puladas): contorno, cor e um brilho fino em cima.
function chain(g, pts, w, color, edge, ew, glow){
  var a = [], i;
  for (i = 0; i < pts.length; i++) { if (pts[i]) a.push(pts[i]); }
  if (a.length < 2) return;
  g.lineCap = 'round'; g.lineJoin = 'round';
  for (var pass = 0; pass < (glow ? 3 : 2); pass++) {
    var off = (pass === 2) ? -w * 0.16 : 0;
    g.strokeStyle = pass === 0 ? edge : (pass === 1 ? color : glow); g.lineWidth = pass === 0 ? w + ew : (pass === 1 ? w : w * 0.26);
    g.beginPath(); g.moveTo(a[0][0] + off, a[0][1] + off);
    for (i = 1; i < a.length; i++) { g.lineTo(a[i][0] + off, a[i][1] + off); }
    g.stroke();
  }
}
function bead(g, p, r, color, edge, ew){ if (!p) return; dot(g, p, r + ew / 2, edge); dot(g, p, r, color); }
function pill(g, x, y, w, h, color){
  var r = h / 2;
  g.fillStyle = color; g.beginPath();
  g.moveTo(x + r, y); g.lineTo(x + w - r, y); g.arc(x + w - r, y + r, r, -1.5708, 1.5708);
  g.lineTo(x + r, y + h); g.arc(x + r, y + r, r, 1.5708, 4.7124); g.fill();
}
// Mão com dedos: palma, quatro dedos que se abrem quando o braço está levantado e o polegar do lado do corpo.
function hand(g, wrist, elbow, toward, size, spread, ew){
  if (!wrist) return;
  var ang = elbow ? Math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0]) : 1.5708;
  var rel = toward ? [toward[0] - wrist[0], toward[1] - wrist[1]] : [0, 0];
  var side = (-Math.sin(ang) * rel[0] + Math.cos(ang) * rel[1]) > 0 ? 1 : -1;
  g.save(); g.translate(wrist[0], wrist[1]); g.rotate(ang);
  g.lineCap = 'round'; g.lineJoin = 'round';
  var fan = [-0.42, -0.14, 0.14, 0.42], len = [0.62, 0.78, 0.74, 0.58], i, pass;
  for (pass = 0; pass < 2; pass++) {
    g.strokeStyle = pass ? SKIN : SKIN_EDGE; g.fillStyle = pass ? SKIN : SKIN_EDGE;
    var w = size * 0.3 + (pass ? 0 : ew);
    g.lineWidth = w;
    for (i = 0; i < 4; i++) {
      var a = fan[i] * (0.35 + 0.65 * spread), x0 = size * 0.7, y0 = (i - 1.5) * size * 0.3;
      g.beginPath(); g.moveTo(x0, y0); g.lineTo(x0 + Math.cos(a) * size * len[i], y0 + Math.sin(a) * size * len[i]); g.stroke();
    }
    var ta = side * (0.7 + 0.5 * spread);
    g.beginPath(); g.moveTo(size * 0.35, side * size * 0.38); g.lineTo(size * 0.35 + Math.cos(ta) * size * 0.62, side * size * 0.38 + Math.sin(ta) * size * 0.62); g.stroke();
    g.beginPath(); g.arc(size * 0.4, 0, size * 0.58 + (pass ? 0 : ew / 2), 0, 6.2832); g.fill();
  }
  g.restore();
}
// Elipse com contorno (sem depender de ctx.ellipse, que TVs antigas não têm).
function oval(g, x, y, rx, ry, rot, fill, edge, ew){
  var pass;
  for (pass = 0; pass < 2; pass++) {
    if (!pass && !edge) continue;
    g.save(); g.translate(x, y); g.rotate(rot); g.scale(pass ? rx : rx + ew / 2, pass ? ry : ry + ew / 2);
    g.fillStyle = pass ? fill : edge; g.beginPath(); g.arc(0, 0, 1, 0, 6.2832); g.fill(); g.restore();
  }
}
// Tênis de lado, com a ponta para fora (como nos desenhos animados): solado branco, biqueira, calcanhar e listra na cor do
// jogador, cadarços e boca do cano. O Vision só dá o tornozelo, então o movimento do pé é deduzido: a canela inclina o tênis,
// o calcanhar sobe quando o joelho dobra (agachado) e o pé que sobe mais que o outro aparece levantado, com a ponta para baixo.
function foot(g, ankle, knee, hip, other, side, u, color, ew){
  if (!ankle) return;
  var tilt = knee ? Math.atan2(ankle[1] - knee[1], ankle[0] - knee[0]) - 1.5708 : 0;
  var heel = 0;
  if (knee && hip) { var shin = Math.max(u * 0.2, ankle[1] - knee[1]); heel = clamp(1 - (knee[1] - hip[1]) / shin, 0, 1); }
  var lift = other ? clamp((other[1] - ankle[1]) / u, 0, 1.2) : 0;
  var rot = tilt * 0.6 + side * (lift * 0.6 + heel * 0.35);
  g.save(); g.translate(ankle[0], ankle[1] + u * 0.1 - heel * u * 0.1); g.rotate(rot); g.scale(side * u, u);
  g.lineJoin = 'round'; g.lineCap = 'round';
  var lw = ew / u;
  function body(){
    g.beginPath(); g.moveTo(-0.30, 0.22); g.lineTo(0.52, 0.22); g.quadraticCurveTo(0.63, 0.22, 0.60, 0.10);
    g.quadraticCurveTo(0.58, -0.01, 0.46, -0.03); g.quadraticCurveTo(0.28, -0.05, 0.14, -0.14); g.lineTo(0.10, -0.27);
    g.lineTo(-0.20, -0.27); g.quadraticCurveTo(-0.35, -0.22, -0.32, 0.02); g.closePath();
  }
  body(); g.fillStyle = '#F6F6FA'; g.fill();
  g.save(); body(); g.clip();
  g.fillStyle = color; g.fillRect(0.38, -0.1, 0.3, 0.4); g.fillRect(-0.4, -0.3, 0.14, 0.6);
  g.strokeStyle = color; g.lineWidth = 0.05; g.beginPath(); g.moveTo(-0.2, 0.06); g.quadraticCurveTo(0.1, 0.0, 0.32, 0.08); g.stroke();
  g.fillStyle = '#FFFFFF'; g.fillRect(-0.4, 0.12, 1.1, 0.12);
  g.restore();
  g.strokeStyle = INK; g.lineWidth = lw; body(); g.stroke();
  g.beginPath(); g.moveTo(-0.31, 0.12); g.lineTo(0.58, 0.12); g.lineWidth = lw * 0.6; g.stroke();
  g.lineWidth = lw * 0.7;
  for (var i = 0; i < 3; i++) { g.beginPath(); g.moveTo(0.1 + i * 0.11, -0.1 + i * 0.015); g.lineTo(0.2 + i * 0.11, -0.2 + i * 0.045 + 0.04); g.strokeStyle = '#8F8FA8'; g.stroke(); }
  g.fillStyle = '#3A3050'; g.beginPath(); g.moveTo(-0.2, -0.27); g.quadraticCurveTo(-0.05, -0.2, 0.1, -0.27); g.quadraticCurveTo(-0.05, -0.33, -0.2, -0.27); g.fill();
  g.restore();
}
function drawHead(g, f, J, r, hair, ew, excited){
  var nose = J.nose, eL = J.eyeL, eR = J.eyeR, aL = J.earL, aR = J.earR, i;
  var roll = 0, cx, cy, yaw = 0;
  var ref = null, span = 0;
  if (eL && eR) { roll = Math.atan2(eR[1] - eL[1], eR[0] - eL[0]); ref = mid(eL, eR); span = Math.sqrt(Math.pow(eR[0] - eL[0], 2) + Math.pow(eR[1] - eL[1], 2)) * 0.8; }
  else if (aL && aR) { roll = Math.atan2(aR[1] - aL[1], aR[0] - aL[0]); ref = mid(aL, aR); span = Math.sqrt(Math.pow(aR[0] - aL[0], 2) + Math.pow(aR[1] - aL[1], 2)) * 0.35; }
  roll = clamp(roll, -0.7, 0.7);
  var cs = Math.cos(roll), sn = Math.sin(roll);
  if (ref) { cx = ref[0] - sn * r * 0.1; cy = ref[1] + cs * r * 0.1; }
  else { cx = nose[0]; cy = nose[1] - r * 0.06; }
  // Virar a cabeça: o nariz sai do meio da linha dos olhos (ou das orelhas).
  if (ref && nose && span > 0) { yaw = clamp(((nose[0] - ref[0]) * cs + (nose[1] - ref[1]) * sn) / span, -1, 1); }
  g.save(); g.translate(cx, cy); g.rotate(roll);
  var fx = yaw * r * 0.42, squeeze = 1 - 0.3 * Math.abs(yaw);
  if (f.host === 'tia') { oval(g, -r * 1.0, r * 0.75, r * 0.3, r * 1.0, 0, '#6B3F2A', null, 0); oval(g, r * 1.0, r * 0.75, r * 0.3, r * 1.0, 0, '#6B3F2A', null, 0); }
  if (!f.host && f.look === 'girl') { oval(g, -r * 1.0, r * 0.6, r * 0.28, r * 0.9, 0, hair, null, 0); oval(g, r * 1.0, r * 0.6, r * 0.28, r * 0.9, 0, hair, null, 0); }
  // orelhas (a que vira para trás encolhe)
  bead(g, [-r * 0.98, r * 0.05], r * 0.2 * (1 - 0.8 * Math.max(0, -yaw)), SKIN, SKIN_EDGE, ew);
  bead(g, [r * 0.98, r * 0.05], r * 0.2 * (1 - 0.8 * Math.max(0, yaw)), SKIN, SKIN_EDGE, ew);
  // rosto com um brilho de luz no alto
  dot(g, [0, 0], r + ew / 2, SKIN_EDGE);
  var skin = g.createRadialGradient(-r * 0.3, -r * 0.35, r * 0.1, 0, 0, r);
  skin.addColorStop(0, '#FFEBD6'); skin.addColorStop(1, SKIN);
  g.fillStyle = skin; g.beginPath(); g.arc(0, 0, r, 0, 6.2832); g.fill();
  // cabelo: calota com franja, acompanha a virada
  g.fillStyle = f.host === 'tia' ? '#6B3F2A' : (f.host === 'tio' ? '#3B2A22' : hair); g.beginPath();
  g.arc(fx * 0.3, 0, r * 1.04, 3.3, 6.12);
  g.quadraticCurveTo(fx * 0.3 + r * 0.55, -r * 0.3, fx * 0.3 + r * 0.1, -r * 0.5);
  g.quadraticCurveTo(fx * 0.3 - r * 0.35, -r * 0.7, fx * 0.3 - r * 1.0, -r * 0.3);
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,0.22)'; g.lineWidth = r * 0.09; g.lineCap = 'round';
  g.beginPath(); g.arc(fx * 0.3, 0, r * 0.82, 3.7, 4.7); g.stroke();
  // rosto: tudo desliza junto quando a cabeça vira
  var ex = r * 0.38 * squeeze, ey = r * 0.02 - (excited ? r * 0.03 : 0);
  dot(g, [fx - r * 0.64 * squeeze, r * 0.4], r * 0.17, 'rgba(255,110,120,0.38)');
  dot(g, [fx + r * 0.64 * squeeze, r * 0.4], r * 0.17, 'rgba(255,110,120,0.38)');
  var sad = f.mood === 'sad';
  if (blinking && !sad) {
    g.strokeStyle = INK; g.lineWidth = Math.max(1.5, r * 0.08);
    g.beginPath(); g.moveTo(fx - ex - r * 0.14, ey); g.lineTo(fx - ex + r * 0.14, ey);
    g.moveTo(fx + ex - r * 0.14, ey); g.lineTo(fx + ex + r * 0.14, ey); g.stroke();
  } else {
    for (i = -1; i <= 1; i += 2) {
      var x = fx + i * ex;
      dot(g, [x, ey], r * (sad ? 0.22 : 0.19), '#fff');
      dot(g, [x + yaw * r * 0.05, ey + r * (sad ? 0.05 : 0.02)], r * (sad ? 0.14 : 0.115), INK);
      dot(g, [x + yaw * r * 0.05 - r * 0.04, ey - r * 0.02], r * (sad ? 0.055 : 0.04), '#fff');
      if (sad) { dot(g, [x + r * 0.05, ey + r * 0.09], r * 0.025, '#fff'); }
    }
  }
  g.strokeStyle = INK; g.lineWidth = Math.max(1.5, r * 0.07);
  var lift = excited ? r * 0.1 : 0;
  for (i = -1; i <= 1; i += 2) {
    if (sad) {
      g.beginPath(); g.moveTo(fx + i * (ex + r * 0.17), ey - r * 0.27); g.lineTo(fx + i * (ex - r * 0.16), ey - r * 0.4); g.stroke();
      continue;
    }
    g.beginPath(); g.moveTo(fx + i * ex - r * 0.15, ey - r * 0.3 - lift); g.quadraticCurveTo(fx + i * ex, ey - r * 0.38 - lift, fx + i * ex + r * 0.15, ey - r * 0.3 - lift); g.stroke();
  }
  // boca: sorriso; aberta e alegre quando os braços estão para cima
  if (sad) {
    var wail = f.sob || 0;
    if (wail > 0.25) {
      g.fillStyle = INK; g.save(); g.translate(fx, r * 0.48); g.scale(r * 0.2, r * (0.08 + 0.2 * wail)); g.beginPath(); g.arc(0, 0, 1, 0, 6.2832); g.fill(); g.restore();
      g.fillStyle = '#FF7A8A'; g.save(); g.translate(fx, r * (0.48 + 0.1 * wail)); g.scale(r * 0.12, r * 0.06 * wail); g.beginPath(); g.arc(0, 0, 1, 0, 6.2832); g.fill(); g.restore();
    } else {
      g.beginPath(); g.arc(fx, r * 0.62, r * 0.26, 3.6, 5.82); g.stroke();
    }
    // lágrimas escorrendo das duas bochechas
    for (i = -1; i <= 1; i += 2) {
      g.strokeStyle = 'rgba(143,216,255,0.55)'; g.lineWidth = r * 0.07;
      g.beginPath(); g.moveTo(fx + i * ex, ey + r * 0.16); g.lineTo(fx + i * (ex + r * 0.14), ey + r * 0.95); g.stroke();
      for (var k = 0; k < 3; k++) {
        var pr = (animT * 0.9 + k / 3 + (i > 0 ? 0.17 : 0)) % 1;
        dot(g, [fx + i * (ex + r * 0.14 * pr), ey + r * 0.18 + pr * r * 0.85], r * 0.075 * (1 - 0.35 * pr), 'rgba(143,216,255,' + (1 - pr * pr * pr) + ')');
      }
    }
  } else if (excited) {
    g.fillStyle = INK; g.beginPath(); g.arc(fx, r * 0.3, r * 0.26, 0, 3.1416); g.closePath(); g.fill();
    g.fillStyle = '#FF7A8A'; g.beginPath(); g.arc(fx, r * 0.5, r * 0.12, 3.1416, 6.2832); g.fill();
  } else {
    g.beginPath(); g.arc(fx, r * 0.2, r * 0.3, 0.4, 2.74); g.stroke();
  }
  if (!f.host && f.look === 'girl') {
    oval(g, r * 0.34, -r * 0.98, r * 0.2, r * 0.12, -0.55, f.color, null, 0); oval(g, r * 0.66, -r * 0.98, r * 0.2, r * 0.12, 0.55, f.color, null, 0);
    dot(g, [r * 0.5, -r * 0.98], r * 0.07, shade(f.color, 0.7));
  }
  if (f.host === 'tio') {
    g.strokeStyle = '#3B2A22'; g.lineWidth = Math.max(1.5, r * 0.06);
    for (i = -1; i <= 1; i += 2) { g.beginPath(); g.arc(fx + i * ex, ey, r * 0.26, 0, 6.2832); g.stroke(); }
    g.beginPath(); g.moveTo(fx - ex + r * 0.26, ey); g.lineTo(fx + ex - r * 0.26, ey); g.stroke();
    g.lineWidth = r * 0.1; g.lineCap = 'round';
    g.beginPath(); g.moveTo(fx - r * 0.3, r * 0.34); g.quadraticCurveTo(fx - r * 0.15, r * 0.22, fx, r * 0.3);
    g.quadraticCurveTo(fx + r * 0.15, r * 0.22, fx + r * 0.3, r * 0.34); g.stroke();
  }
  if (f.crown) {
    var cy0 = -r * 0.88;
    g.fillStyle = '#FFC83D'; g.strokeStyle = '#B5791A'; g.lineWidth = Math.max(1.5, r * 0.07); g.lineJoin = 'round';
    g.beginPath(); g.moveTo(-r * 0.62, cy0); g.lineTo(-r * 0.66, cy0 - r * 0.5); g.lineTo(-r * 0.3, cy0 - r * 0.26); g.lineTo(0, cy0 - r * 0.68);
    g.lineTo(r * 0.3, cy0 - r * 0.26); g.lineTo(r * 0.66, cy0 - r * 0.5); g.lineTo(r * 0.62, cy0); g.closePath(); g.fill(); g.stroke();
    dot(g, [0, cy0 - r * 0.08], r * 0.07, '#E0523C'); dot(g, [-r * 0.36, cy0 - r * 0.06], r * 0.05, '#4D9DE0'); dot(g, [r * 0.36, cy0 - r * 0.06], r * 0.05, '#36C9A6');
    var pulse = 0.6 + 0.4 * Math.sin(animT * 9);
    g.fillStyle = 'rgba(255,255,255,0.9)';
    for (i = -1; i <= 1; i += 2) {
      var sx = i * r * 1.35, sy = -r * (0.7 + 0.2 * Math.sin(animT * 5 + i)), sz = r * 0.2 * pulse;
      g.beginPath(); g.moveTo(sx, sy - sz); g.lineTo(sx + sz * 0.3, sy - sz * 0.3); g.lineTo(sx + sz, sy); g.lineTo(sx + sz * 0.3, sy + sz * 0.3);
      g.lineTo(sx, sy + sz); g.lineTo(sx - sz * 0.3, sy + sz * 0.3); g.lineTo(sx - sz, sy); g.lineTo(sx - sz * 0.3, sy - sz * 0.3); g.closePath(); g.fill();
    }
  }
  g.restore();
  return [cx, cy];
}
function drawAvatar(g, f, ox, oy, bw, bh){
  function P(k){ var p = f.joints[k]; return p ? [ox + p[0] * bw, oy + p[1] * bh] : null; }
  var ls = P('ls'), rs = P('rs'), lh = P('lh'), rh = P('rh'), nose = P('n');
  var u = (ls && rs) ? Math.abs(ls[0] - rs[0]) : ((lh && rh) ? Math.abs(lh[0] - rh[0]) * 1.2 : bh * 0.08);
  u = f.u ? f.u * bh : clamp(u, bh * 0.045, bh * 0.22);
  var shirt = f.color, shirtEdge = shade(f.color, 0.42), pants = shade(f.color, 0.55), pantsEdge = shade(f.color, 0.3);
  var glow = 'rgba(255,255,255,0.28)', hair = shade(f.color, 0.42), ew = Math.max(1.5, u * 0.09);
  // Sem ombros à vista, usa o nariz como referência do tronco.
  if (!(ls && rs) && nose) { ls = [nose[0] - u * 0.5, nose[1] + u * 0.9]; rs = [nose[0] + u * 0.5, nose[1] + u * 0.9]; }
  var la = P('la'), ra = P('ra'), lw = P('lw'), rw = P('rw'), le = P('le'), re = P('re');
  var eyes = [P('ley'), P('rey')], ears = [P('lea'), P('rea')];
  if (eyes[0] && eyes[1] && eyes[0][0] > eyes[1][0]) { eyes.reverse(); }
  if (ears[0] && ears[1] && ears[0][0] > ears[1][0]) { ears.reverse(); }
  var raised = (lw && ls && lw[1] < ls[1] - u * 0.2) || (rw && rs && rw[1] < rs[1] - u * 0.2);
  g.globalAlpha = f.ready ? 1 : 0.6;

  // sombra no chão
  var feet = mid(la, ra);
  if (f.floor !== undefined) { feet = [feet ? feet[0] : (nose ? nose[0] : ox + bw / 2), oy + f.floor * bh]; }
  if (feet) {
    g.fillStyle = 'rgba(0,0,0,0.22)'; g.beginPath();
    if (g.ellipse) { g.ellipse(feet[0], feet[1] + u * 0.2, u * 1.1, u * 0.22, 0, 0, 6.2832); } else { g.arc(feet[0], feet[1] + u * 0.2, u * 0.6, 0, 6.2832); }
    g.fill();
  }

  // pernas e tênis
  chain(g, [lh, P('lk'), la], u * 0.52, pants, pantsEdge, ew, glow);
  chain(g, [rh, P('rk'), ra], u * 0.52, pants, pantsEdge, ew, glow);
  var hipMid = mid(lh, rh), i;
  var legs = [[la, P('lk'), lh, ra], [ra, P('rk'), rh, la]];
  for (i = 0; i < 2; i++) {
    var anchor = legs[i][0], sideOf = (hipMid && anchor) ? (anchor[0] < hipMid[0] ? -1 : 1) : (i ? 1 : -1);
    foot(g, anchor, legs[i][1], legs[i][2], legs[i][3], sideOf, u, shirt, ew);
  }

  // tronco: camisa com degradê e contorno, cantos arredondados, cinto
  var hipsL = lh, hipsR = rh;
  if (ls && rs && !(lh && rh)) { hipsL = [ls[0], ls[1] + u * 1.7]; hipsR = [rs[0], rs[1] + u * 1.7]; }
  var neckBase = mid(ls, rs);
  if (nose && neckBase) { chain(g, [nose, neckBase], u * 0.42, SKIN, SKIN_EDGE, ew); }
  if (ls && rs && hipsL && hipsR) {
    var round = u * 0.38, top = Math.min(ls[1], rs[1]), bottom = Math.max(hipsL[1], hipsR[1]);
    var body = g.createLinearGradient(0, top, 0, bottom);
    body.addColorStop(0, tint(shirt, 0.28)); body.addColorStop(0.45, shirt); body.addColorStop(1, shade(shirt, 0.82));
    for (var pass = 0; pass < 2; pass++) {
      g.fillStyle = pass ? body : shirtEdge; g.strokeStyle = pass ? body : shirtEdge;
      g.lineJoin = 'round'; g.lineWidth = round + (pass ? 0 : ew * 2);
      g.beginPath(); g.moveTo(ls[0], ls[1]); g.lineTo(rs[0], rs[1]); g.lineTo(hipsR[0], hipsR[1]); g.lineTo(hipsL[0], hipsL[1]); g.closePath();
      g.fill(); g.stroke();
    }
    // cinto com fivela
    g.strokeStyle = INK; g.lineWidth = u * 0.13; g.lineCap = 'butt';
    g.beginPath(); g.moveTo(hipsL[0], hipsL[1] - u * 0.06); g.lineTo(hipsR[0], hipsR[1] - u * 0.06); g.stroke();
    var beltMid = mid(hipsL, hipsR); dot(g, [beltMid[0], beltMid[1] - u * 0.06], u * 0.1, '#FFC845');
    // estrela no peito e gola
    var chest = [(ls[0] + rs[0]) / 2, (ls[1] + rs[1]) / 2 + u * 0.55];
    g.fillStyle = 'rgba(255,255,255,0.8)'; g.beginPath();
    for (i = 0; i < 10; i++) {
      var rad = (i % 2 ? 0.1 : 0.23) * u, an = -1.5708 + i * 0.6283;
      g.lineTo(chest[0] + Math.cos(an) * rad, chest[1] + Math.sin(an) * rad);
    }
    g.closePath(); g.fill();
    dot(g, neckBase, u * 0.2, SKIN);
  }

  // braços: manga curta na cor da camisa, antebraço de pele, mão com dedos
  chain(g, [ls, le], u * 0.46, shirt, shirtEdge, ew, glow);
  chain(g, [rs, re], u * 0.46, shirt, shirtEdge, ew, glow);
  chain(g, [le, lw], u * 0.36, SKIN, SKIN_EDGE, ew, glow);
  chain(g, [re, rw], u * 0.36, SKIN, SKIN_EDGE, ew, glow);
  var bodyMid = mid(neckBase, mid(hipsL, hipsR));
  var spreadL = (lw && ls && lw[1] < ls[1]) ? 1 : 0.25, spreadR = (rw && rs && rw[1] < rs[1]) ? 1 : 0.25;
  hand(g, lw, le, bodyMid, u * 0.36, spreadL, ew);
  hand(g, rw, re, bodyMid, u * 0.36, spreadR, ew);

  // cabeça e plaquinha com o nome
  if (nose) {
    var r = f.r ? f.r * bh : u * 0.74;
    var c = drawHead(g, f, { nose: nose, eyeL: eyes[0], eyeR: eyes[1], earL: ears[0], earR: ears[1] }, r, hair, ew, raised);
    if (f.host) { g.globalAlpha = 1; return; }
    g.font = 'bold ' + Math.round(bh * 0.06) + 'px Arial'; g.textAlign = 'center'; g.textBaseline = 'middle';
    var label = f.name + (f.mood === 'win' ? ' ★' : (f.mood === 'sad' ? '' : (f.ready ? ' ✓' : ' !'))), tw = g.measureText(label).width, ph = bh * 0.085;
    var py = Math.max(oy + ph * 0.1, c[1] - r * 1.15 - ph * 1.25);
    pill(g, c[0] - tw / 2 - ph * 0.45, py, tw + ph * 0.9, ph, 'rgba(0,0,0,0.55)');
    g.fillStyle = f.color; g.fillText(label, c[0], py + ph / 2 + 1);
    g.textBaseline = 'alphabetic';
  }
  g.globalAlpha = 1;
}

var DANCE = [
  { L: [2.6, 2.9], R: [2.6, 2.9] },   // braços em V
  { L: [2.9, 3.1], R: [0.9, 0.7] },   // dedo para o alto (disco)
  { L: [1.2, 2.9], R: [1.2, 2.9] },   // punhos fechados
  { L: [0.9, 0.7], R: [2.9, 3.1] }
];
function smooth(x){ x = clamp(x, 0, 1); return x * x * (3 - 2 * x); }
function lerp(a, b, t){ return a + (b - a) * t; }
// Monta o esqueleto (mesmos nomes das juntas do Vision) em "unidades de altura", ancorado nos pés do jogador.
function figureJoints(b, aspect, spec){
  var J = {};
  function put(name, dx, dy){ J[name] = [b.cx + dx * b.k / aspect, b.floor + dy * b.k]; }
  function arm(side, sh, aU, aF, pre){
    var ex = sh[0] + side * Math.sin(aU) * 0.11, ey = sh[1] + Math.cos(aU) * 0.11;
    put('le'.replace('l', pre), ex, ey);
    put('lw'.replace('l', pre), ex + side * Math.sin(aF) * 0.11, ey + Math.cos(aF) * 0.11);
  }
  var sh = spec.shoulderY, hw = spec.shoulderW;
  put('n', spec.headX, spec.headY);
  put('ley', spec.headX - 0.027, spec.headY - 0.015 - spec.tilt); put('rey', spec.headX + 0.027, spec.headY - 0.015 + spec.tilt);
  put('lea', spec.headX - 0.057, spec.headY - 0.008 - spec.tilt); put('rea', spec.headX + 0.057, spec.headY - 0.008 + spec.tilt);
  put('ls', spec.shX - hw, sh); put('rs', spec.shX + hw, sh);
  arm(-1, [spec.shX - hw, sh], spec.armL[0], spec.armL[1], 'l'); arm(1, [spec.shX + hw, sh], spec.armR[0], spec.armR[1], 'r');
  put('lh', spec.hipX - 0.036, spec.hipY); put('rh', spec.hipX + 0.036, spec.hipY);
  put('lk', spec.hipX - spec.kneeW, spec.kneeY); put('rk', spec.hipX + spec.kneeW, spec.kneeY);
  put('la', -spec.footW, spec.footY); put('ra', spec.footW, spec.footY);
  return J;
}
function danceSpec(t){
  var beat = t / 0.55, bi = Math.floor(beat), ph = beat - bi, e = smooth(ph);
  var from = DANCE[bi % 4], to = DANCE[(bi + 1) % 4];
  var hop = Math.max(0, Math.sin(Math.PI * ph)), squat = (1 - hop) * 0.014, lift = hop * 0.04;
  var sway = Math.sin(beat * Math.PI) * 0.022, y = squat - lift;
  return { headX: sway * 0.25, headY: -0.68 + y, tilt: sway * 0.5, shoulderY: -0.58 + y, shoulderW: 0.071, shX: -sway * 0.3,
           hipX: sway * 0.5, hipY: -0.32 + squat * 0.5 - lift, kneeW: 0.036 + (1 - hop) * 0.02, kneeY: -0.16 - lift * 0.5 + squat * 0.5,
           footW: 0.036 + (1 - hop) * 0.012, footY: -lift * 0.9,
           armL: [lerp(from.L[0], to.L[0], e), lerp(from.L[1], to.L[1], e)], armR: [lerp(from.R[0], to.R[0], e), lerp(from.R[1], to.R[1], e)] };
}
function sadSpec(t){
  var sob = Math.max(0, Math.sin(6.2832 * t / 1.3)), sob2 = sob * sob, shake = Math.sin(6.2832 * 9 * t) * 0.004 * sob2;
  var slump = 0.03, drop = 0.05, sway = Math.sin(6.2832 * t / 2.6);
  function wipe(offset){ var p = (((t + offset) % 2.6) + 2.6) % 2.6 / 1.1; return p < 1 ? Math.sin(Math.PI * p) : 0; }
  var wl = wipe(0), wr = wipe(1.3);
  return { sob: sob2, headX: sway * 0.006, headY: -0.68 + slump + drop + sob2 * 0.008, tilt: sway * 0.012,
           shoulderY: -0.58 + slump + shake, shoulderW: 0.06, shX: 0, hipX: 0, hipY: -0.31, kneeW: 0.028, kneeY: -0.155,
           footW: 0.045, footY: 0,
           armL: [lerp(0.12, 0.5, wl), lerp(0.05, -2.55, wl) + Math.sin(t * 18) * 0.1 * wl],
           armR: [lerp(0.12, 0.5, wr), lerp(0.05, -2.55, wr) + Math.sin(t * 18) * 0.1 * wr] };
}

export { drawAvatar, figureJoints, danceSpec, sadSpec, lerp, smooth, clamp };
