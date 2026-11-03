// swiftlint:disable line_length type_body_length
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
    <video id="replay" muted loop autoplay playsinline></video>
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
    var SKIN = '#FFD9B8', SKIN_EDGE = '#C98F6A', blinking = false;
    function shade(hex, f){
      var n = parseInt(hex.replace('#', ''), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
      return 'rgb(' + Math.round(r * f) + ',' + Math.round(g * f) + ',' + Math.round(b * f) + ')';
    }
    function mid(a, b){ return (a && b) ? [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2] : (a || b); }
    function dot(g, p, r, color){ if (!p) return; g.fillStyle = color; g.beginPath(); g.arc(p[0], p[1], r, 0, 6.2832); g.fill(); }
    // Membro de um ou mais segmentos (juntas que faltam são puladas), com contorno escuro por baixo.
    function chain(g, pts, w, color, edge, ew){
      var a = [], i;
      for (i = 0; i < pts.length; i++) { if (pts[i]) a.push(pts[i]); }
      if (a.length < 2) return;
      g.lineCap = 'round'; g.lineJoin = 'round';
      for (var pass = 0; pass < 2; pass++) {
        g.strokeStyle = pass ? color : edge; g.lineWidth = pass ? w : w + ew;
        g.beginPath(); g.moveTo(a[0][0], a[0][1]);
        for (i = 1; i < a.length; i++) { g.lineTo(a[i][0], a[i][1]); }
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
    function drawAvatar(g, f, ox, oy, bw, bh){
      function P(k){ var p = f.joints[k]; return p ? [ox + p[0] * bw, oy + p[1] * bh] : null; }
      var ls = P('ls'), rs = P('rs'), lh = P('lh'), rh = P('rh'), nose = P('n');
      var u = (ls && rs) ? Math.abs(ls[0] - rs[0]) : ((lh && rh) ? Math.abs(lh[0] - rh[0]) * 1.2 : bh * 0.08);
      u = Math.max(bh * 0.045, Math.min(bh * 0.22, u));
      var shirt = f.color, shirtEdge = shade(f.color, 0.45), pants = shade(f.color, 0.55), pantsEdge = shade(f.color, 0.3);
      var hair = shade(f.color, 0.42), ew = Math.max(1.5, u * 0.09);
      // Sem ombros à vista, usa o nariz como referência do tronco.
      if (!(ls && rs) && nose) { ls = [nose[0] - u * 0.5, nose[1] + u * 0.9]; rs = [nose[0] + u * 0.5, nose[1] + u * 0.9]; }
      var la = P('la'), ra = P('ra');
      g.globalAlpha = f.ready ? 1 : 0.6;

      // sombra no chão
      var feet = mid(la, ra);
      if (feet) { g.fillStyle = 'rgba(0,0,0,0.22)'; g.beginPath(); g.ellipse ? g.ellipse(feet[0], feet[1] + u * 0.2, u * 1.1, u * 0.22, 0, 0, 6.2832) : g.arc(feet[0], feet[1] + u * 0.2, u * 0.6, 0, 6.2832); g.fill(); }

      // pernas e tênis
      chain(g, [lh, P('lk'), la], u * 0.52, pants, pantsEdge, ew);
      chain(g, [rh, P('rk'), ra], u * 0.52, pants, pantsEdge, ew);
      var feetAt = [la, ra];
      for (var i = 0; i < 2; i++) {
        var a = feetAt[i];
        if (a) {
          // tênis: meia-lua branca com solado na cor do jogador
          g.fillStyle = '#2B2140'; g.beginPath(); g.arc(a[0], a[1], u * 0.34 + ew / 2, 3.1416, 6.2832); g.fill();
          g.fillStyle = '#F4F4F8'; g.beginPath(); g.arc(a[0], a[1], u * 0.34, 3.1416, 6.2832); g.fill();
          g.fillStyle = shirt; g.fillRect(a[0] - u * 0.34, a[1] - u * 0.02, u * 0.68, u * 0.1);
        }
      }

      // tronco: camisa com contorno, cantos arredondados
      var hipsL = lh, hipsR = rh;
      if (ls && rs && !(lh && rh)) { hipsL = [ls[0], ls[1] + u * 1.7]; hipsR = [rs[0], rs[1] + u * 1.7]; }
      var neckBase = mid(ls, rs);
      if (nose && neckBase) { chain(g, [nose, neckBase], u * 0.42, SKIN, SKIN_EDGE, ew); }
      if (ls && rs && hipsL && hipsR) {
        var round = u * 0.38;
        for (var pass = 0; pass < 2; pass++) {
          g.fillStyle = pass ? shirt : shirtEdge; g.strokeStyle = pass ? shirt : shirtEdge;
          g.lineJoin = 'round'; g.lineWidth = round + (pass ? 0 : ew * 2);
          g.beginPath(); g.moveTo(ls[0], ls[1]); g.lineTo(rs[0], rs[1]); g.lineTo(hipsR[0], hipsR[1]); g.lineTo(hipsL[0], hipsL[1]); g.closePath();
          g.fill(); g.stroke();
        }
        // faixa clara no peito e gola
        g.strokeStyle = 'rgba(255,255,255,0.28)'; g.lineWidth = u * 0.16; g.lineCap = 'round';
        var chest = [(ls[0] + hipsL[0]) / 2 + u * 0.05, (ls[1] + hipsL[1]) / 2];
        g.beginPath(); g.moveTo(ls[0] + u * 0.2, ls[1] + u * 0.3); g.lineTo(chest[0] + u * 0.1, chest[1]); g.stroke();
        dot(g, neckBase, u * 0.2, SKIN);
      }

      // braços: manga curta na cor da camisa, antebraço e mão de pele
      chain(g, [ls, P('le')], u * 0.46, shirt, shirtEdge, ew);
      chain(g, [rs, P('re')], u * 0.46, shirt, shirtEdge, ew);
      chain(g, [P('le'), P('lw')], u * 0.36, SKIN, SKIN_EDGE, ew);
      chain(g, [P('re'), P('rw')], u * 0.36, SKIN, SKIN_EDGE, ew);
      bead(g, P('lw'), u * 0.24, SKIN, SKIN_EDGE, ew);
      bead(g, P('rw'), u * 0.24, SKIN, SKIN_EDGE, ew);

      // cabeça
      if (nose) {
        var r = u * 0.74, cx = nose[0], cy = nose[1] - r * 0.06;
        bead(g, [cx - r * 0.98, cy + r * 0.05], r * 0.2, SKIN, SKIN_EDGE, ew);
        bead(g, [cx + r * 0.98, cy + r * 0.05], r * 0.2, SKIN, SKIN_EDGE, ew);
        bead(g, [cx, cy], r, SKIN, SKIN_EDGE, ew);
        // cabelo: calota com franja
        g.fillStyle = hair; g.beginPath();
        g.arc(cx, cy, r * 1.04, 3.3, 6.12);
        g.quadraticCurveTo(cx + r * 0.55, cy - r * 0.3, cx + r * 0.1, cy - r * 0.5);
        g.quadraticCurveTo(cx - r * 0.35, cy - r * 0.7, cx - r * 1.0, cy - r * 0.3);
        g.fill();
        // olhos, sobrancelhas, bochechas e sorriso
        var ex = r * 0.38, ey = cy + r * 0.04;
        g.fillStyle = 'rgba(255,110,120,0.35)';
        dot(g, [cx - r * 0.62, cy + r * 0.38], r * 0.17, 'rgba(255,110,120,0.35)');
        dot(g, [cx + r * 0.62, cy + r * 0.38], r * 0.17, 'rgba(255,110,120,0.35)');
        if (blinking) {
          g.strokeStyle = '#2B2140'; g.lineWidth = Math.max(1.5, r * 0.08); g.lineCap = 'round';
          g.beginPath(); g.moveTo(cx - ex - r * 0.14, ey); g.lineTo(cx - ex + r * 0.14, ey);
          g.moveTo(cx + ex - r * 0.14, ey); g.lineTo(cx + ex + r * 0.14, ey); g.stroke();
        } else {
          dot(g, [cx - ex, ey], r * 0.17, '#fff'); dot(g, [cx + ex, ey], r * 0.17, '#fff');
          dot(g, [cx - ex, ey + r * 0.02], r * 0.1, '#2B2140'); dot(g, [cx + ex, ey + r * 0.02], r * 0.1, '#2B2140');
          dot(g, [cx - ex - r * 0.03, ey - r * 0.03], r * 0.035, '#fff'); dot(g, [cx + ex - r * 0.03, ey - r * 0.03], r * 0.035, '#fff');
        }
        g.strokeStyle = '#2B2140'; g.lineWidth = Math.max(1.5, r * 0.09); g.lineCap = 'round';
        g.beginPath(); g.arc(cx, cy + r * 0.2, r * 0.3, 0.4, 2.74); g.stroke();
        // nome numa plaquinha acima da cabeça
        g.font = 'bold ' + Math.round(bh * 0.06) + 'px Arial'; g.textAlign = 'center'; g.textBaseline = 'middle';
        var label = f.name + (f.ready ? ' ✓' : ' !'), tw = g.measureText(label).width, ph = bh * 0.085;
        var py = Math.max(oy + ph * 0.1, cy - r * 1.15 - ph * 1.25);
        pill(g, cx - tw / 2 - ph * 0.45, py, tw + ph * 0.9, ph, 'rgba(0,0,0,0.55)');
        g.fillStyle = f.color; g.fillText(label, cx, py + ph / 2 + 1);
        g.textBaseline = 'alphabetic';
      }
      g.globalAlpha = 1;
    }
    function stageBox(c){
      // Resolução de verdade da tela (TVs 4K), com limite de 2x para não pesar.
      var dpr = Math.min(2, window.devicePixelRatio || 1), W = c.clientWidth, H = c.clientHeight, aspect = lastPose.aspect || 1.7778;
      var pw = Math.round(W * dpr), ph = Math.round(H * dpr);
      if (c.width !== pw || c.height !== ph) { c.width = pw; c.height = ph; }
      var bw = W, bh = W / aspect;
      if (bh > H) { bh = H; bw = H * aspect; }
      return { W: W, H: H, dpr: dpr, ox: (W - bw) / 2, oy: (H - bh) / 2, bw: bw, bh: bh };
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
    // Replay em vídeo (só com o código de acesso na URL): cobre a tela na hora do resultado.
    function showReplay(s){
      var v = el('replay'), src = (s.screen === 'result' && s.replay && camCode) ? (s.replay + '&t=' + camCode) : null;
      if (src) {
        if (v.getAttribute('data-src') !== src) {
          v.setAttribute('data-src', src); v.src = src; v.load();
          var p = v.play(); if (p && p.catch) p.catch(function(){});
        }
        v.style.display = 'block';
      } else {
        if (v.getAttribute('data-src')) { v.pause(); v.removeAttribute('src'); v.removeAttribute('data-src'); v.load(); }
        v.style.display = 'none';
      }
      return !!src;
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
// swiftlint:enable line_length type_body_length
