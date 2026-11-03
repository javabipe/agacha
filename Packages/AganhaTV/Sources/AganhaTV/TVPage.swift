// swiftlint:disable line_length type_body_length file_length
/// Página que a TV abre. Escrita em JavaScript simples (ES5) para funcionar em navegadores de TV mais antigos.
enum TVPage {
    static let html = #"""
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Agacha! na TV</title>
    <style>
    html,body{margin:0;height:100%;overflow:hidden;background:#1B1433;color:#fff;font-family:Arial,Helvetica,sans-serif}
    #bg{position:absolute;left:0;top:0;right:0;bottom:0;background:#1B1433}
    #center{position:absolute;left:0;right:0;top:0;bottom:44vh;display:flex;align-items:center;justify-content:center}
    #tia{width:30vh;height:30vh;margin-right:4vw;display:none}
    #word{font-size:22vh;font-weight:900;text-align:center;text-shadow:0 .6vh 1.2vh rgba(0,0,0,.4)}
    #banner{font-size:9vh;font-weight:800;text-align:center;padding:0 4vw;line-height:1.1}
    #message{position:absolute;left:0;right:0;top:3vh;text-align:center;font-size:7vh;font-weight:800;color:#FFC845}
    #cam{position:absolute;display:none;background:#000}
    #replay{position:absolute;left:0;top:0;width:100%;height:100%;background:#000;display:none}
    #message.pill{left:2vw;right:auto;text-align:left;padding:1.2vh 2.4vw;border-radius:5vh;background:rgba(0,0,0,.6)}
    #note{position:absolute;left:2vw;bottom:9vh;font-size:3vh;color:rgba(255,255,255,.9);background:rgba(0,0,0,.55);padding:.6vh 1.4vw;border-radius:1vh;display:none}
    #stage{position:absolute;left:0;top:60vh;width:100%;height:33vh;display:none}
    #players{position:absolute;left:0;right:0;bottom:1vh;text-align:center}
    .chip{display:inline-block;margin:.4vh .8vw;padding:.8vh 1.6vw;border-radius:6vh;background:rgba(0,0,0,.4);font-size:3.6vh}
    .chip.out{opacity:.4}
    .dot{display:inline-block;width:3vh;height:3vh;border-radius:50%;margin-right:.8vw;vertical-align:middle}
    #status{position:absolute;right:2vw;top:2vh;font-size:2.6vh;opacity:.8}
    #sound{position:absolute;left:0;right:0;bottom:0;padding:2vh;text-align:center;font-size:3.4vh;background:#FFC845;color:#1B1433;font-weight:700}
    </style>
    </head>
    <body>
    <div id="bg"></div>
    <canvas id="replay"></canvas>
    <div id="message"></div>
    <img id="cam" alt="">
    <canvas id="stage"></canvas>
    <div id="center">
      <svg id="tia" viewBox="0 0 200 200">
        <line id="armL" x1="70" y1="100" x2="70" y2="165" stroke="#FFD9B8" stroke-width="16" stroke-linecap="round"/>
        <line id="armR" x1="130" y1="100" x2="130" y2="165" stroke="#FFD9B8" stroke-width="16" stroke-linecap="round"/>
        <rect x="55" y="82" width="90" height="100" rx="26" fill="#8E7BFF"/>
        <circle cx="100" cy="52" r="34" fill="#FFD9B8"/>
        <circle cx="88" cy="48" r="4" fill="#000"/><circle cx="112" cy="48" r="4" fill="#000"/>
        <path d="M86 64 Q100 76 114 64" stroke="#000" stroke-width="4" fill="none" stroke-linecap="round"/>
      </svg>
      <div><div id="word"></div><div id="banner"></div></div>
    </div>
    <div id="note"></div>
    <div id="players"></div>
    <div id="status">Conectando…</div>
    <div id="sound">Aperte OK (ou qualquer tecla) no controle para ligar o som</div>
    <script>
    var unlocked = false, ctx = null, buffers = {}, pending = {}, active = [], epoch = 0;
    var fallback = null, total = 0, loaded = 0;
    var lastState = { screen: 'menu', players: [] }, lastPose = { figures: [] };
    var camCode = (location.search.match(/[?&]t=([0-9]+)/) || [])[1];
    function el(id){ return document.getElementById(id); }

    // ---------- avatares (desenhados a partir das juntas do corpo, nunca da imagem)
    var SKIN = '#FFD9B8', SKIN_EDGE = '#B97F5C', INK = '#2B2140', blinking = false;
    var QUALITY = parseFloat((location.search.match(/[?&]q=([0-9.]+)/) || [])[1]) || 1.5;
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
      // orelhas (a que vira para trás encolhe)
      bead(g, [-r * 0.98, r * 0.05], r * 0.2 * (1 - 0.8 * Math.max(0, -yaw)), SKIN, SKIN_EDGE, ew);
      bead(g, [r * 0.98, r * 0.05], r * 0.2 * (1 - 0.8 * Math.max(0, yaw)), SKIN, SKIN_EDGE, ew);
      // rosto com um brilho de luz no alto
      dot(g, [0, 0], r + ew / 2, SKIN_EDGE);
      var skin = g.createRadialGradient(-r * 0.3, -r * 0.35, r * 0.1, 0, 0, r);
      skin.addColorStop(0, '#FFEBD6'); skin.addColorStop(1, SKIN);
      g.fillStyle = skin; g.beginPath(); g.arc(0, 0, r, 0, 6.2832); g.fill();
      // cabelo: calota com franja, acompanha a virada
      g.fillStyle = hair; g.beginPath();
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
      if (blinking) {
        g.strokeStyle = INK; g.lineWidth = Math.max(1.5, r * 0.08);
        g.beginPath(); g.moveTo(fx - ex - r * 0.14, ey); g.lineTo(fx - ex + r * 0.14, ey);
        g.moveTo(fx + ex - r * 0.14, ey); g.lineTo(fx + ex + r * 0.14, ey); g.stroke();
      } else {
        for (i = -1; i <= 1; i += 2) {
          var x = fx + i * ex;
          dot(g, [x, ey], r * 0.19, '#fff');
          dot(g, [x + yaw * r * 0.05, ey + r * 0.02], r * 0.115, INK);
          dot(g, [x + yaw * r * 0.05 - r * 0.035, ey - r * 0.03], r * 0.04, '#fff');
        }
      }
      g.strokeStyle = INK; g.lineWidth = Math.max(1.5, r * 0.07);
      var lift = excited ? r * 0.1 : 0;
      for (i = -1; i <= 1; i += 2) {
        g.beginPath(); g.moveTo(fx + i * ex - r * 0.15, ey - r * 0.3 - lift); g.quadraticCurveTo(fx + i * ex, ey - r * 0.38 - lift, fx + i * ex + r * 0.15, ey - r * 0.3 - lift); g.stroke();
      }
      // boca: sorriso; aberta e alegre quando os braços estão para cima
      if (excited) {
        g.fillStyle = INK; g.beginPath(); g.arc(fx, r * 0.3, r * 0.26, 0, 3.1416); g.closePath(); g.fill();
        g.fillStyle = '#FF7A8A'; g.beginPath(); g.arc(fx, r * 0.5, r * 0.12, 3.1416, 6.2832); g.fill();
      } else {
        g.beginPath(); g.arc(fx, r * 0.2, r * 0.3, 0.4, 2.74); g.stroke();
      }
      g.restore();
      return [cx, cy];
    }
    function drawAvatar(g, f, ox, oy, bw, bh){
      function P(k){ var p = f.joints[k]; return p ? [ox + p[0] * bw, oy + p[1] * bh] : null; }
      var ls = P('ls'), rs = P('rs'), lh = P('lh'), rh = P('rh'), nose = P('n');
      var u = (ls && rs) ? Math.abs(ls[0] - rs[0]) : ((lh && rh) ? Math.abs(lh[0] - rh[0]) * 1.2 : bh * 0.08);
      u = clamp(u, bh * 0.045, bh * 0.22);
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
      if (feet) {
        g.fillStyle = 'rgba(0,0,0,0.22)'; g.beginPath();
        if (g.ellipse) { g.ellipse(feet[0], feet[1] + u * 0.2, u * 1.1, u * 0.22, 0, 0, 6.2832); } else { g.arc(feet[0], feet[1] + u * 0.2, u * 0.6, 0, 6.2832); }
        g.fill();
      }

      // pernas e tênis
      chain(g, [lh, P('lk'), la], u * 0.52, pants, pantsEdge, ew, glow);
      chain(g, [rh, P('rk'), ra], u * 0.52, pants, pantsEdge, ew, glow);
      var feetAt = [la, ra], i;
      for (i = 0; i < 2; i++) {
        var a = feetAt[i];
        if (a) {
          g.fillStyle = INK; g.beginPath(); g.arc(a[0], a[1], u * 0.34 + ew / 2, 3.1416, 6.2832); g.fill();
          g.fillStyle = '#F4F4F8'; g.beginPath(); g.arc(a[0], a[1], u * 0.34, 3.1416, 6.2832); g.fill();
          g.fillStyle = shirt; g.fillRect(a[0] - u * 0.34, a[1] - u * 0.02, u * 0.68, u * 0.1);
        }
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
        var r = u * 0.74;
        var c = drawHead(g, f, { nose: nose, eyeL: eyes[0], eyeR: eyes[1], earL: ears[0], earR: ears[1] }, r, hair, ew, raised);
        g.font = 'bold ' + Math.round(bh * 0.06) + 'px Arial'; g.textAlign = 'center'; g.textBaseline = 'middle';
        var label = f.name + (f.ready ? ' ✓' : ' !'), tw = g.measureText(label).width, ph = bh * 0.085;
        var py = Math.max(oy + ph * 0.1, c[1] - r * 1.15 - ph * 1.25);
        pill(g, c[0] - tw / 2 - ph * 0.45, py, tw + ph * 0.9, ph, 'rgba(0,0,0,0.55)');
        g.fillStyle = f.color; g.fillText(label, c[0], py + ph / 2 + 1);
        g.textBaseline = 'alphabetic';
      }
      g.globalAlpha = 1;
    }
    function stageBox(c){
      // Resolução maior que a da tela (mínimo 1,5x, até 2x) para as bordas ficarem lisas; `?q=1` desliga.
      var scale = Math.min(2, Math.max(window.devicePixelRatio || 1, QUALITY)), W = c.clientWidth, H = c.clientHeight, aspect = lastPose.aspect || 1.7778;
      var pw = Math.round(W * scale), ph = Math.round(H * scale);
      if (c.width !== pw || c.height !== ph) { c.width = pw; c.height = ph; }
      var bw = W, bh = W / aspect;
      if (bh > H) { bh = H; bw = H * aspect; }
      return { W: W, H: H, dpr: scale, ox: (W - bw) / 2, oy: (H - bh) / 2, bw: bw, bh: bh };
    }
    // Os avatares deslizam até a posição mais nova (em vez de saltar), o que esconde tremidas e deixa o movimento fluido.
    var shown = [], gliding = false;
    function nextFrame(f){
      var r = window.requestAnimationFrame || window.webkitRequestAnimationFrame;
      if (r) { r(f); } else { setTimeout(f, 16); }
    }
    function glide(){
      var targets = lastPose.figures || [], moving = false, k = 0.6, next = [];
      for (var i = 0; i < targets.length; i++) {
        var t = targets[i], cur = null;
        for (var j = 0; j < shown.length; j++) { if (shown[j].name === t.name && shown[j].color === t.color) { cur = shown[j]; break; } }
        var from = cur ? cur.joints : {}, joints = {};
        for (var key in t.joints) {
          var to = t.joints[key], old = from[key];
          if (!old) { joints[key] = [to[0], to[1]]; continue; }
          var x = old[0] + (to[0] - old[0]) * k, y = old[1] + (to[1] - old[1]) * k;
          if (Math.abs(to[0] - x) > 0.0006 || Math.abs(to[1] - y) > 0.0006) { moving = true; } else { x = to[0]; y = to[1]; }
          joints[key] = [x, y];
        }
        next.push({ name: t.name, color: t.color, ready: t.ready, joints: joints });
      }
      shown = next;
      drawStage();
      if (moving) { nextFrame(glide); } else { gliding = false; }
    }
    function drawStage(){
      var c = el('stage');
      if (!c.getContext || c.style.display === 'none') return;
      var g = c.getContext('2d'), b = stageBox(c);
      g.setTransform(b.dpr, 0, 0, b.dpr, 0, 0);
      g.clearRect(0, 0, b.W, b.H);
      var cam = el('cam');
      if (cam.style.display === 'block') {
        cam.style.left = (c.offsetLeft + b.ox) + 'px'; cam.style.top = (c.offsetTop + b.oy) + 'px';
        cam.style.width = b.bw + 'px'; cam.style.height = b.bh + 'px';
      } else {
        g.fillStyle = 'rgba(255,255,255,0.07)'; g.fillRect(b.ox, b.oy, b.bw, b.bh);
      }
      g.strokeStyle = 'rgba(255,255,255,0.35)'; g.lineWidth = 3; g.strokeRect(b.ox, b.oy, b.bw, b.bh);
      for (var i = 0; i < shown.length; i++) { drawAvatar(g, shown[i], b.ox, b.oy, b.bw, b.bh); }
    }

    // ---------- tela
    function setArms(g){
      var up = (g === 'up'), l = up ? 150 : 18, r = up ? -150 : -18;
      el('armL').setAttribute('transform', 'rotate(' + l + ' 70 100)');
      el('armR').setAttribute('transform', 'rotate(' + r + ' 130 100)');
    }
    // Replay (só com o código de acesso na URL): baixa os quadros e os toca em ciclo cobrindo a tela do resultado.
    // Só troca o layout quando todos os quadros chegaram; até lá a tela normal do resultado continua.
    var replayKey = null, replayOn = false, replayTimer = null;
    function stopReplay(){
      if (replayTimer) { clearTimeout(replayTimer); replayTimer = null; }
      replayKey = null; replayOn = false;
    }
    function startReplay(r){
      var key = r.version + ':' + r.frames;
      if (key === replayKey) return;
      stopReplay(); replayKey = key;
      var imgs = [], loaded = 0;
      for (var i = 0; i < r.frames; i++) {
        (function(i){
          var im = new Image();
          im.onload = im.onerror = function(){
            loaded++;
            if (replayKey === key && loaded === r.frames) { playReplay(imgs, r.fps, key); }
          };
          im.src = '/replay/' + i + '.jpg?v=' + r.version + '&t=' + camCode;
          imgs.push(im);
        })(i);
      }
    }
    function playReplay(imgs, fps, key){
      var c = el('replay'), g = c.getContext('2d'), k = 0;
      replayOn = true; render(lastState);
      function tick(){
        if (replayKey !== key) return;
        var im = imgs[k], W = c.clientWidth || window.innerWidth, H = c.clientHeight || window.innerHeight;
        if (c.width !== W || c.height !== H) { c.width = W; c.height = H; }
        g.fillStyle = '#000'; g.fillRect(0, 0, c.width, c.height);
        if (im.naturalWidth) {
          var sc = Math.min(c.width / im.naturalWidth, c.height / im.naturalHeight), w = im.naturalWidth * sc, h = im.naturalHeight * sc;
          g.drawImage(im, (c.width - w) / 2, (c.height - h) / 2, w, h);
        }
        k = (k + 1) % imgs.length;
        replayTimer = setTimeout(tick, k === 0 ? 700 : 1000 / fps);
      }
      tick();
    }
    function showReplay(s){
      if (s.screen === 'result' && s.replay && camCode) { startReplay(s.replay); }
      else { stopReplay(); }
      el('replay').style.display = replayOn ? 'block' : 'none';
      return replayOn;
    }
    function render(s){
      lastState = s;
      var video = showReplay(s);
      var positioning = (s.screen === 'positioning');
      var playing = (s.screen === 'play' || s.screen === 'result');
      var play = (s.screen === 'play' && s.word);
      var stage = el('stage'), cam = el('cam');
      el('bg').style.background = (s.word && s.background) ? s.background : 'linear-gradient(#1B1433,#3A2A6B)';
      el('word').textContent = s.word || '';
      el('banner').textContent = positioning ? '' : (s.banner || (s.screen === 'menu' ? 'Agacha!' : ''));
      el('message').textContent = positioning ? (s.banner || '') : (s.message || '');
      el('center').style.display = (positioning || video) ? 'none' : 'flex';
      el('message').className = video ? 'pill' : '';
      el('note').style.display = (s.screen === 'result' && s.note && video) ? 'block' : 'none';
      el('note').textContent = s.note || '';
      el('tia').style.display = playing ? 'block' : 'none';
      stage.style.display = ((positioning || playing) && !video) ? 'block' : 'none';
      stage.style.top = positioning ? '17vh' : '60vh';
      stage.style.height = positioning ? '66vh' : '33vh';
      var showCam = positioning && camCode;
      if (showCam && !cam.getAttribute('data-on')) { cam.src = '/camera.mjpg?t=' + camCode; cam.setAttribute('data-on', '1'); }
      cam.style.display = (showCam && !video) ? 'block' : 'none';
      setArms(play ? s.gesture : null);
      var html = '';
      for (var i = 0; i < (s.players || []).length; i++) {
        var p = s.players[i];
        html += '<span class="chip' + (p.out ? ' out' : '') + '"><span class="dot" style="background:' + p.color + '"></span>'
              + p.name.replace(/</g, '&lt;') + (p.detail ? ' ' + p.detail : '') + '</span>';
      }
      el('players').innerHTML = html;
      drawStage();
    }
    function pose(p){
      lastPose = p;
      if (!gliding) { gliding = true; nextFrame(glide); }
    }

    // ---------- som (Web Audio: sem o limite de elementos de áudio das TVs)
    function audioContext(){
      if (ctx) return ctx;
      var C = window.AudioContext || window.webkitAudioContext;
      if (C) { try { ctx = new C(); } catch (e) { ctx = null; } }
      return ctx;
    }
    function soundStatus(){
      if (!unlocked) return;
      var box = el('sound');
      box.style.display = (total && loaded < total) ? 'block' : 'none';
      box.textContent = 'Carregando sons… ' + loaded + '/' + total;
    }
    function loadClip(name, done){
      if (buffers[name]) { if (done) done(buffers[name]); return; }
      if (pending[name]) { pending[name].push(done); return; }
      pending[name] = [done];
      function finish(buf){
        var list = pending[name] || []; delete pending[name];
        if (buf) { buffers[name] = buf; loaded++; soundStatus(); }
        for (var i = 0; i < list.length; i++) { if (list[i]) list[i](buf); }
      }
      var x = new XMLHttpRequest();
      x.open('GET', '/audio/' + name + '.wav'); x.responseType = 'arraybuffer';
      x.onload = function(){
        if (x.status !== 200) { finish(null); return; }
        try { ctx.decodeAudioData(x.response, function(b){ finish(b); }, function(){ finish(null); }); } catch (e) { finish(null); }
      };
      x.onerror = function(){ finish(null); };
      x.send();
    }
    function preload(names){
      total = names.length; var next = 0, running = 0;
      function pump(){
        while (running < 2 && next < names.length) {
          running++;
          loadClip(names[next++], function(){ running--; pump(); });
        }
      }
      pump(); soundStatus();
    }
    function playClip(name){
      if (!unlocked) return;
      var mine = epoch;
      if (!audioContext()) {
        if (!fallback) fallback = new Audio();
        fallback.src = '/audio/' + name + '.wav';
        var p = fallback.play(); if (p && p.catch) p.catch(function(){});
        return;
      }
      loadClip(name, function(buf){
        if (!buf || mine !== epoch) return;
        var src = ctx.createBufferSource();
        src.buffer = buf; src.connect(ctx.destination);
        if (src.start) { src.start(0); } else { src.noteOn(0); }
        active.push(src);
      });
    }
    function stopAll(){
      epoch++;
      for (var i = 0; i < active.length; i++) { try { if (active[i].stop) { active[i].stop(0); } else { active[i].noteOff(0); } } catch (e) {} }
      active = [];
      if (fallback) { try { fallback.pause(); } catch (e) {} }
    }
    function unlock(){
      if (unlocked) return;
      unlocked = true;
      var c = audioContext();
      if (c) {
        try { if (c.resume) c.resume(); var silent = c.createBuffer(1, 1, 22050), s = c.createBufferSource();
              s.buffer = silent; s.connect(c.destination); if (s.start) { s.start(0); } } catch (e) {}
        var x = new XMLHttpRequest();
        x.open('GET', '/clips');
        x.onload = function(){ try { preload(JSON.parse(x.responseText)); } catch (e) {} };
        x.send();
      }
      el('sound').style.display = 'none';
    }
    document.addEventListener('keydown', unlock);
    document.addEventListener('click', unlock);
    document.addEventListener('touchstart', unlock);

    // ---------- conexão
    function connect(){
      var es = new EventSource('/events');
      es.addEventListener('state', function(e){ el('status').textContent = ''; render(JSON.parse(e.data)); });
      es.addEventListener('pose', function(e){ pose(JSON.parse(e.data)); });
      es.addEventListener('audio', function(e){ playClip(e.data); });
      es.addEventListener('stop', stopAll);
      es.onerror = function(){ el('status').textContent = 'Reconectando…'; };
    }
    setArms(null);
    // Piscadinha a cada poucos segundos (só redesenha, sem animação contínua).
    setInterval(function(){
      blinking = true; drawStage();
      setTimeout(function(){ blinking = false; drawStage(); }, 140);
    }, 3600);
    connect();
    </script>
    </body>
    </html>
    """#
}
// swiftlint:enable line_length type_body_length file_length
