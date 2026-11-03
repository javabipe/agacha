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
    /* ---- modo pontuação */
    #fx{position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;display:none}
    #board{position:absolute;right:2vw;top:61vh;width:30vw;height:33vh;display:none}
    .row{position:absolute;left:0;width:100%;display:flex;align-items:center;-webkit-transition:top .45s ease;transition:top .45s ease}
    .row .crown{width:4.6vh;height:4vh;margin-right:.6vw;opacity:0}
    .row .crown.on{opacity:1}
    .row .nm{width:9vw;font-weight:800;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-shadow:0 .3vh .6vh rgba(0,0,0,.5)}
    .row .track{position:relative;-webkit-box-flex:1;flex:1;height:55%;border-radius:3vh;background:rgba(0,0,0,.35);overflow:hidden}
    .row .fill{position:absolute;left:0;top:0;bottom:0;width:0;border-radius:3vh;-webkit-transition:width .3s ease;transition:width .3s ease}
    .row .cnt{display:flex;align-items:center;min-width:8vw;justify-content:flex-end;font-weight:900;text-shadow:0 .3vh .6vh rgba(0,0,0,.5)}
    .coin{display:inline-block;width:.9em;height:.9em;border-radius:50%;margin-right:.35em;background:#FFC83D;border:.14em solid #B5791A;box-sizing:border-box;box-shadow:inset 0 0 0 .1em #FFE88A}
    .mult{min-width:3.6vw;text-align:center;font-weight:900;color:#FFD54A;opacity:0;text-shadow:0 0 1.2vh rgba(255,200,40,.9)}
    .mult.on{opacity:1}
    @-webkit-keyframes bumpA{0%{-webkit-transform:scale(1)}35%{-webkit-transform:scale(1.35)}100%{-webkit-transform:scale(1)}}
    @keyframes bumpA{0%{transform:scale(1)}35%{transform:scale(1.35)}100%{transform:scale(1)}}
    .bump{-webkit-animation:bumpA .28s ease-out;animation:bumpA .28s ease-out}
    .pop{position:absolute;text-align:center;font-weight:900;white-space:nowrap;pointer-events:none;-webkit-transform:translate(-50%,-100%);transform:translate(-50%,-100%);
      -webkit-animation:popUpA 1.5s ease-out forwards;animation:popUpA 1.5s ease-out forwards;text-shadow:0 .5vh 1.4vh rgba(0,0,0,.65),0 0 2vh rgba(255,255,255,.35)}
    .pop .sub{font-size:.55em;font-weight:800;color:#fff}
    .pop.miss{-webkit-animation:missA 1.4s ease-out forwards;animation:missA 1.4s ease-out forwards}
    @-webkit-keyframes popUpA{0%{opacity:0;-webkit-transform:translate(-50%,-60%) scale(.3)}14%{opacity:1;-webkit-transform:translate(-50%,-110%) scale(1.3)}28%{-webkit-transform:translate(-50%,-110%) scale(1)}78%{opacity:1}100%{opacity:0;-webkit-transform:translate(-50%,-190%) scale(1)}}
    @keyframes popUpA{0%{opacity:0;transform:translate(-50%,-60%) scale(.3)}14%{opacity:1;transform:translate(-50%,-110%) scale(1.3)}28%{transform:translate(-50%,-110%) scale(1)}78%{opacity:1}100%{opacity:0;transform:translate(-50%,-190%) scale(1)}}
    @-webkit-keyframes missA{0%{opacity:0;-webkit-transform:translate(-50%,-100%)}10%{opacity:1;-webkit-transform:translate(-56%,-100%)}20%{-webkit-transform:translate(-44%,-100%)}30%{-webkit-transform:translate(-54%,-100%)}40%{-webkit-transform:translate(-48%,-100%)}50%{-webkit-transform:translate(-50%,-100%)}80%{opacity:1}100%{opacity:0;-webkit-transform:translate(-50%,-130%)}}
    @keyframes missA{0%{opacity:0;transform:translate(-50%,-100%)}10%{opacity:1;transform:translate(-56%,-100%)}20%{transform:translate(-44%,-100%)}30%{transform:translate(-54%,-100%)}40%{transform:translate(-48%,-100%)}50%{transform:translate(-50%,-100%)}80%{opacity:1}100%{opacity:0;transform:translate(-50%,-130%)}}
    </style>
    </head>
    <body>
    <div id="bg"></div>
    <canvas id="replay"></canvas>
    <div id="message"></div>
    <img id="cam" alt="">
    <canvas id="stage"></canvas>
    <div id="center">
      <canvas id="tia"></canvas>
      <div><div id="word"></div><div id="banner"></div></div>
    </div>
    <div id="note"></div>
    <div id="board"></div>
    <canvas id="fx"></canvas>
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
    // Elipse com contorno (sem depender de ctx.ellipse, que TVs antigas não têm).
    function oval(g, x, y, rx, ry, rot, fill, edge, ew){
      var pass;
      for (pass = 0; pass < 2; pass++) {
        if (!pass && !edge) continue;
        g.save(); g.translate(x, y); g.rotate(rot); g.scale(pass ? rx : rx + ew / 2, pass ? ry : ry + ew / 2);
        g.fillStyle = pass ? fill : edge; g.beginPath(); g.arc(0, 0, 1, 0, 6.2832); g.fill(); g.restore();
      }
    }
    // Tênis: o Vision só dá o tornozelo, então o pé é deduzido: a canela inclina o tênis, o calcanhar sobe quando
    // o joelho dobra muito (agachado), e o pé que sobe mais que o outro aparece levantado.
    function foot(g, ankle, knee, hip, other, side, u, color, ew){
      if (!ankle) return;
      var tilt = knee ? Math.atan2(ankle[1] - knee[1], ankle[0] - knee[0]) - 1.5708 : 0;
      var heel = 0;
      if (knee && hip) { var shin = Math.max(u * 0.2, ankle[1] - knee[1]); heel = clamp(1 - (knee[1] - hip[1]) / shin, 0, 1); }
      var lift = other ? clamp((other[1] - ankle[1]) / u, 0, 1.2) : 0;
      var rot = side * 0.18 + tilt * 0.8 + side * lift * 0.5 + heel * side * 0.1;
      var cx = ankle[0] + side * u * 0.1, cy = ankle[1] + u * (0.1 - heel * 0.1);
      g.save(); g.translate(cx, cy); g.rotate(rot); g.scale(1, 1 - heel * 0.3 - lift * 0.1);
      oval(g, 0, u * 0.12, u * 0.4, u * 0.17, 0, '#2B2140', null, 0);
      oval(g, side * u * 0.02, u * 0.04, u * 0.38, u * 0.19, 0, '#F6F6FA', INK, ew);
      oval(g, side * u * 0.22, u * 0.07, u * 0.17, u * 0.12, 0, color, null, 0);
      g.strokeStyle = '#B9B9C8'; g.lineWidth = Math.max(1, u * 0.035); g.lineCap = 'round';
      for (var i = 0; i < 3; i++) { g.beginPath(); g.moveTo(-u * 0.12 + i * u * 0.1, -u * 0.06); g.lineTo(-u * 0.12 + i * u * 0.1 + side * u * 0.03, u * 0.03); g.stroke(); }
      oval(g, -side * u * 0.12, -u * 0.07, u * 0.12, u * 0.06, 0, '#4B4166', null, 0);
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
      var targets = ending ? endingFigures() : (lastPose.figures || []), moving = !!ending, k = 0.6, next = [];
      animT = Date.now() / 1000;
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
        next.push({ name: t.name, color: t.color, ready: t.ready, joints: joints, mood: t.mood, crown: t.crown, floor: t.floor, sob: t.sob });
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
    // Apresentador (tia ou tio): o mesmo desenho dos jogadores, só o busto; os braços sobem em "vivo" e descem em "morto".
    var host = { kind: 'tia', raise: 0, target: 0, bounce: 0, last: null, running: false };
    function hostFrame(){
      var c = el('tia');
      host.raise += (host.target - host.raise) * 0.3; host.bounce *= 0.88;
      if (c.clientWidth) {
        var scale = Math.min(2, Math.max(window.devicePixelRatio || 1, QUALITY)), W = c.clientWidth;
        if (c.width !== Math.round(W * scale)) { c.width = c.height = Math.round(W * scale); }
        var g = c.getContext('2d'), j = {}, sy = 0.72 - host.bounce * 0.03, b = host.bounce * 0.03;
        function lerpA(x, y){ return x + (y - x) * host.raise; }
        var up = lerpA(0.3, 2.45), fo = lerpA(0.12, 2.9);
        j.n = [0.5, 0.42 - b]; j.ley = [0.44, 0.395 - b]; j.rey = [0.56, 0.395 - b]; j.lea = [0.385, 0.405 - b]; j.rea = [0.615, 0.405 - b];
        j.ls = [0.30, sy]; j.rs = [0.70, sy];
        var sides = [['l', -1, 0.30], ['r', 1, 0.70]];
        for (var i = 0; i < 2; i++) {
          var ex = sides[i][2] + sides[i][1] * Math.sin(up) * 0.23, ey = sy + Math.cos(up) * 0.23;
          j[sides[i][0] + 'e'] = [ex, ey]; j[sides[i][0] + 'w'] = [ex + sides[i][1] * Math.sin(fo) * 0.2, ey + Math.cos(fo) * 0.2];
        }
        g.setTransform(scale, 0, 0, scale, 0, 0); g.clearRect(0, 0, W, W);
        drawAvatar(g, { name: '', color: host.kind === 'tio' ? '#4D9DE0' : '#8E7BFF', ready: true, joints: j, u: 0.40, r: 0.2, host: host.kind }, 0, 0, W, W);
      }
      if (Math.abs(host.target - host.raise) > 0.004 || host.bounce > 0.01) { nextFrame(hostFrame); } else { host.running = false; }
    }
    function setArms(g, kind){
      host.kind = kind || host.kind;
      host.target = (g === 'up') ? 1 : 0;
      if (g && g !== host.last) { host.bounce = 1; }
      host.last = g || null;
      if (!host.running) { host.running = true; nextFrame(hostFrame); }
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
      stage.style.display = ((positioning || playing || (s.screen === 'gameover' && s.winners)) && !video) ? 'block' : 'none';
      stage.style.top = positioning ? '17vh' : '60vh';
      stage.style.height = positioning ? '66vh' : '33vh';
      var showCam = positioning && camCode;
      if (showCam && !cam.getAttribute('data-on')) { cam.src = '/camera.mjpg?t=' + camCode; cam.setAttribute('data-on', '1'); }
      cam.style.display = (showCam && !video) ? 'block' : 'none';
      setArms(play ? s.gesture : null, s.host);
      var html = '';
      for (var i = 0; i < (s.players || []).length; i++) {
        var p = s.players[i];
        html += '<span class="chip' + (p.out ? ' out' : '') + '"><span class="dot" style="background:' + p.color + '"></span>'
              + p.name.replace(/</g, '&lt;') + (p.detail ? ' ' + p.detail : '') + '</span>';
      }
      el('players').innerHTML = html;
      renderScore(s.score);
      updateEnding(s);
      drawStage();
    }
    function pose(p){
      lastPose = p;
      for (var q = 0; q < (p.figures || []).length; q++) {
        var fj = p.figures[q].joints, base = (fj.la && fj.ra) ? Math.max(fj.la[1], fj.ra[1]) : 0;
        if (fj.n && base) { tallest[p.figures[q].name] = Math.max(tallest[p.figures[q].name] || 0, base - fj.n[1]); }
      }
      if (!gliding) { gliding = true; nextFrame(glide); }
    }

    // ---------- resultado: dancinha da vitória e choro de quem perdeu (poses desenhadas por código, em ciclo)
    var ending = null, confetti = [], tallest = {}, animT = 0;
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
    function baseOf(f){
      var j = f.joints, floor = (j.la && j.ra) ? Math.max(j.la[1], j.ra[1]) : (j.la ? j.la[1] : (j.ra ? j.ra[1] : 0.9));
      var hm = mid(j.lh, j.rh) || mid(j.ls, j.rs) || j.n || [0.5, 0.5], h = tallest[f.name] || 0.68;
      return { cx: hm[0], floor: floor, k: clamp(h, 0.4, 0.9) / 0.68 };
    }
    function endingFigures(){
      var live = lastPose.figures || [], out = [], t = (Date.now() - ending.t0) / 1000, aspect = lastPose.aspect || 1.7778;
      for (var i = 0; i < live.length; i++) {
        var f = live[i], b = ending.base[f.name] || (ending.base[f.name] = baseOf(f)), win = !!ending.win[f.name];
        var spec = win ? danceSpec(t + i * 0.1) : sadSpec(t + i * 0.25);
        out.push({ name: f.name, color: f.color, ready: true, joints: figureJoints(b, aspect, spec), mood: win ? 'win' : 'sad',
                   crown: win, floor: b.floor, sob: spec.sob || 0 });
      }
      return out;
    }
    function updateEnding(s){
      var on = (s.screen === 'gameover' && s.winners && s.winners.length > 0), i;
      if (on && !ending) {
        ending = { t0: Date.now(), win: {}, base: {} }; confetti = [];
        if (!gliding) { gliding = true; nextFrame(glide); }
        fxStart();
      } else if (!on && ending) { ending = null; confetti = []; }
      if (ending) { ending.win = {}; for (i = 0; i < s.winners.length; i++) { ending.win[s.winners[i]] = 1; } }
      el('fx').style.display = (ending || board.round !== null) ? 'block' : 'none';
    }
    function drawConfetti(g, W, H, dt){
      var colors = ['#FFC845', '#36C9A6', '#FF7AB8', '#4D9DE0', '#FF9F1C', '#8E7BFF'], keep = [], i;
      if (ending) { for (i = 0; i < 3 && confetti.length < 70; i++) { confetti.push({ x: Math.random() * W, y: -10, vy: H * (0.16 + Math.random() * 0.2), vx: (Math.random() - 0.5) * W * 0.06, rot: Math.random() * 6, vr: (Math.random() - 0.5) * 8, w: H * 0.014, h: H * 0.026, c: colors[Math.floor(Math.random() * colors.length)] }); } }
      for (i = 0; i < confetti.length; i++) {
        var p = confetti[i]; p.y += p.vy * dt; p.x += p.vx * dt + Math.sin(p.y * 0.01 + p.rot) * 0.6; p.rot += p.vr * dt;
        if (p.y > H + 20) continue;
        g.save(); g.translate(p.x, p.y); g.rotate(p.rot); g.fillStyle = p.c; g.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); g.restore();
        keep.push(p);
      }
      confetti = keep;
    }

    // ---------- modo pontuação: moedas que saltam do avatar até o placar, selos de rapidez e combo
    var board = { round: null, names: [], total: {}, pending: {}, built: '', rows: [] };
    var parts = [], sparks = [], fxRunning = false, lastDing = 0;
    var TIERS = {
      perfect: { text: 'PERFEITO!', color: '#FFD54A' }, great: { text: 'ÓTIMO!', color: '#7CFFB2' },
      good: { text: 'BOA!', color: '#FFFFFF' }, held: { text: 'MANTEVE!', color: '#CFD8FF' }, miss: { text: 'ERROU', color: '#FF8A80' }
    };
    function shownCoins(name){ return Math.max(0, (board.total[name] || 0) - (board.pending[name] || 0)); }
    function secondsText(ms){ return (ms / 1000).toFixed(2).replace('.', ',') + ' s'; }
    function crownSvg(){
      return '<svg viewBox="0 0 46 40" style="width:100%;height:100%"><polygon points="3,34 6,10 16,22 23,4 30,22 40,10 43,34" fill="#FFC83D" stroke="#B5791A" stroke-width="3" stroke-linejoin="round"/>'
        + '<circle cx="6" cy="9" r="3.4" fill="#FFE88A"/><circle cx="23" cy="4" r="3.4" fill="#FFE88A"/><circle cx="40" cy="9" r="3.4" fill="#FFE88A"/></svg>';
    }
    function buildBoard(entries){
      var key = '', html = '', i;
      for (i = 0; i < entries.length; i++) { key += entries[i].name + '|' + entries[i].color + ';'; }
      if (key === board.built) return;
      board.built = key; board.names = []; board.rows = [];
      for (i = 0; i < entries.length; i++) {
        board.names.push(entries[i].name);
        html += '<div class="row" id="row' + i + '"><div class="crown">' + crownSvg() + '</div>'
          + '<div class="nm" style="color:' + entries[i].color + '"></div><div class="track"><div class="fill" style="background:' + entries[i].color + '"></div></div>'
          + '<div class="cnt"><span class="coin"></span><span class="num">0</span></div><div class="mult"></div></div>';
      }
      el('board').innerHTML = html;
      for (i = 0; i < entries.length; i++) {
        var row = el('row' + i);
        row.querySelector('.nm').textContent = entries[i].name;
        board.rows.push({ row: row, crown: row.querySelector('.crown'), fill: row.querySelector('.fill'), num: row.querySelector('.num'),
                          mult: row.querySelector('.mult'), coin: row.querySelector('.coin'), shownMult: 1 });
      }
    }
    function layoutBoard(){
      var n = board.names.length, i, top = 0, order = [];
      if (!n) return;
      var rh = Math.min(10, 33 / n), fs = rh * 0.42;
      for (i = 0; i < n; i++) { order.push(i); top = Math.max(top, shownCoins(board.names[i])); }
      order.sort(function(a, b){ return (shownCoins(board.names[b]) - shownCoins(board.names[a])) || (a - b); });
      var scale = Math.max(10, top);
      for (i = 0; i < n; i++) {
        var k = order[i], r = board.rows[k], v = shownCoins(board.names[k]);
        r.row.style.top = (i * rh) + 'vh'; r.row.style.height = rh + 'vh'; r.row.style.fontSize = fs + 'vh';
        r.fill.style.width = Math.min(100, v / scale * 100) + '%';
        r.num.textContent = v;
        r.crown.className = 'crown' + ((v > 0 && v === top) ? ' on' : '');
      }
    }
    function anchorOf(name, where){
      var figs = lastPose.figures || [], c = el('stage'), f = null, i;
      for (i = 0; i < figs.length; i++) { if (figs[i].name === name) { f = figs[i]; break; } }
      if (!f || !f.joints.n) return { x: window.innerWidth * 0.5, y: window.innerHeight * 0.7 };
      var b = stageBox(c), j = f.joints, p = j.n;
      if (where === 'chest' && j.ls && j.rs) { p = [(j.ls[0] + j.rs[0]) / 2, (j.ls[1] + j.rs[1]) / 2 + 0.05]; }
      return { x: c.offsetLeft + b.ox + p[0] * b.bw, y: c.offsetTop + b.oy + p[1] * b.bh };
    }
    function judgement(e, index, count){
      var t = TIERS[e.tier]; if (!t) return;
      var a = anchorOf(e.name, 'head'), d = document.createElement('div');
      var size = count <= 2 ? 5.6 : (count === 3 ? 4.4 : 3.6);
      d.className = 'pop' + (e.tier === 'miss' ? ' miss' : '');
      d.style.left = a.x + 'px'; d.style.top = (a.y - window.innerHeight * (0.09 + (index % 3) * 0.085)) + 'px';
      d.style.fontSize = size + 'vh'; d.style.color = t.color;
      var sub = '';
      if (e.tier !== 'miss') {
        sub = (e.double ? 'DUPLO · ' : '') + (e.ms !== null && e.ms !== undefined ? secondsText(e.ms) + ' · ' : '') + '+' + e.gain + (e.multiplier > 1 ? ' · x' + e.multiplier : '');
      }
      d.innerHTML = t.text + (sub ? '<div class="sub">' + sub + '</div>' : '');
      document.body.appendChild(d);
      setTimeout(function(){ if (d.parentNode) d.parentNode.removeChild(d); }, 1600);
    }
    function ding(){
      var now = Date.now(); if (!unlocked || now - lastDing < 60) return; lastDing = now;
      var c = audioContext(); if (!c) return;
      try {
        var o = c.createOscillator(), g = c.createGain(), t = c.currentTime;
        o.type = 'square'; o.frequency.setValueAtTime(1175, t); o.frequency.setValueAtTime(1568, t + 0.06);
        g.gain.setValueAtTime(0.05, t); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
        o.connect(g); g.connect(c.destination); o.start(t); o.stop(t + 0.2);
      } catch (e) {}
    }
    function spawnCoins(e, index){
      var n = Math.min(12, e.gain), k = board.names.indexOf(e.name), start = anchorOf(e.name, 'chest'), H = window.innerHeight;
      if (k < 0 || n < 1) return;
      var base = Math.floor(e.gain / n), extra = e.gain - base * n, now = Date.now();
      for (var i = 0; i < n; i++) {
        parts.push({ x: start.x, y: start.y, vx: (Math.random() - 0.5) * H * 0.55, vy: -H * (0.55 + Math.random() * 0.4),
                     rot: Math.random() * 6, spin: 8 + Math.random() * 8, born: now + i * 45, fly: 0, name: e.name, k: k,
                     val: base + (i < extra ? 1 : 0), r: H * 0.022 });
      }
      for (i = 0; i < 6; i++) {
        var ang = Math.random() * 6.2832, sp = H * (0.2 + Math.random() * 0.3);
        sparks.push({ x: start.x, y: start.y, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp - H * 0.2, life: 0.5, max: 0.5, r: H * 0.006 });
      }
    }
    function land(p){
      board.pending[p.name] = Math.max(0, (board.pending[p.name] || 0) - p.val);
      layoutBoard();
      var r = board.rows[p.k];
      if (r) { restart(r.coin, 'bump'); }
      for (var i = 0; i < 3; i++) { var a = Math.random() * 6.2832; sparks.push({ x: p.x, y: p.y, vx: Math.cos(a) * 220, vy: Math.sin(a) * 220, life: 0.3, max: 0.3, r: window.innerHeight * 0.005 }); }
      ding();
    }
    function restart(node, cls){
      var kept = (node.getAttribute('class') || '').replace(cls, '').replace(/^\s+|\s+$/g, '');
      node.setAttribute('class', kept);
      void node.getBoundingClientRect();
      node.setAttribute('class', kept ? kept + ' ' + cls : cls);
    }
    function drawCoin(g, p){
      var sx = Math.max(0.18, Math.abs(Math.cos(p.rot))), r = p.r;
      g.save(); g.translate(p.x, p.y); g.scale(sx, 1);
      g.fillStyle = '#B5791A'; g.beginPath(); g.arc(0, 0, r, 0, 6.2832); g.fill();
      g.fillStyle = '#FFC83D'; g.beginPath(); g.arc(0, 0, r * 0.84, 0, 6.2832); g.fill();
      g.strokeStyle = '#FFE88A'; g.lineWidth = r * 0.16; g.beginPath(); g.arc(0, 0, r * 0.56, 0, 6.2832); g.stroke();
      g.fillStyle = 'rgba(255,255,255,0.75)'; g.beginPath(); g.arc(-r * 0.35, -r * 0.4, r * 0.16, 0, 6.2832); g.fill();
      g.restore();
    }
    var fxLast = 0;
    function fxFrame(){
      var c = el('fx'), W = window.innerWidth, H = window.innerHeight, now = Date.now(), dt = Math.min(0.05, (now - fxLast) / 1000), i;
      fxLast = now;
      if (c.width !== W || c.height !== H) { c.width = W; c.height = H; }
      // posições dos contadores (lidas antes de qualquer escrita no DOM)
      var targets = [];
      for (i = 0; i < board.rows.length; i++) {
        var rc = board.rows[i].coin.getBoundingClientRect();
        targets.push([rc.left + rc.width / 2, rc.top + rc.height / 2]);
      }
      var g = c.getContext('2d'), alive = [], landed = [], gravity = H * 2.4;
      g.clearRect(0, 0, W, H);
      for (i = 0; i < parts.length; i++) {
        var p = parts[i];
        if (now < p.born) { alive.push(p); continue; }
        if (!p.fly) {
          p.vy += gravity * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.spin * dt;
          if (p.vy > 0 && now - p.born > 500) { p.fly = 0.001; }
        } else {
          var t = targets[p.k];
          if (!t) { landed.push(p); continue; }
          p.fly += dt; p.rot += p.spin * dt;
          var dx = t[0] - p.x, dy = t[1] - p.y, dist = Math.sqrt(dx * dx + dy * dy), sp = H * (0.6 + 2.6 * p.fly) * dt;
          if (dist <= sp + 8) { landed.push(p); continue; }
          p.x += dx / dist * sp; p.y += dy / dist * sp;
        }
        drawCoin(g, p); alive.push(p);
      }
      parts = alive;
      for (i = 0; i < landed.length; i++) { land(landed[i]); }
      var keep = [];
      for (i = 0; i < sparks.length; i++) {
        var s = sparks[i]; s.life -= dt;
        if (s.life <= 0) continue;
        s.x += s.vx * dt; s.y += s.vy * dt; s.vy += H * 0.8 * dt;
        g.globalAlpha = Math.max(0, s.life / s.max); g.fillStyle = '#FFF3B0';
        g.beginPath(); g.arc(s.x, s.y, s.r, 0, 6.2832); g.fill();
        keep.push(s);
      }
      g.globalAlpha = 1; sparks = keep;
      drawConfetti(g, W, H, dt);
      if (parts.length || sparks.length || confetti.length || ending) { nextFrame(fxFrame); } else { fxRunning = false; g.clearRect(0, 0, W, H); }
    }
    function fxStart(){ if (!fxRunning) { fxRunning = true; fxLast = Date.now(); nextFrame(fxFrame); } }
    function renderScore(sc){
      var on = !!(sc && sc.entries && sc.entries.length), i;
      el('board').style.display = on ? 'block' : 'none';
      el('fx').style.display = (on || ending) ? 'block' : 'none';
      el('players').style.display = on ? 'none' : 'block';
      if (!on) { board.round = null; board.built = ''; parts = []; sparks = []; board.pending = {}; return; }
      buildBoard(sc.entries);
      var trigger = (board.round !== null && sc.round > board.round);
      if (board.round !== null && sc.round < board.round) { parts = []; sparks = []; board.pending = {}; }
      board.round = sc.round;
      for (i = 0; i < sc.entries.length; i++) { board.total[sc.entries[i].name] = sc.entries[i].total; }
      if (trigger) {
        for (i = 0; i < sc.entries.length; i++) {
          var e = sc.entries[i];
          board.pending[e.name] = (board.pending[e.name] || 0) + e.gain;
          judgement(e, i, sc.entries.length);
          spawnCoins(e, i);
          var r = board.rows[i];
          if (r) {
            r.mult.textContent = e.multiplier > 1 ? 'x' + e.multiplier : '';
            r.mult.className = 'mult' + (e.multiplier > 1 ? ' on' : '');
            if (e.multiplier > r.shownMult) { restart(r.mult, 'bump'); }
            r.shownMult = e.multiplier;
          }
        }
        fxStart();
        setTimeout(function(){ board.pending = {}; layoutBoard(); }, 3200);
      } else {
        for (i = 0; i < sc.entries.length; i++) {
          var r2 = board.rows[i];
          if (r2 && sc.entries[i].multiplier <= 1 && sc.entries[i].combo === 0) { r2.mult.className = 'mult'; r2.shownMult = 1; }
        }
      }
      layoutBoard();
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
