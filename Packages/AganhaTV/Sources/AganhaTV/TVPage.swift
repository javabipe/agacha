// swiftlint:disable line_length type_body_length
/// Página que a TV abre. Escrita em JavaScript simples (ES5) para funcionar em navegadores de TV mais antigos.
/// Para ver a página renderizada: `scripts/render_tv_page.swift`.
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
    #replay{position:absolute;left:0;top:0;width:100%;height:100%;background:#000;display:none}
    #top{position:absolute;left:0;right:0;top:0;height:17vh;text-align:center}
    #word{display:inline-block;margin-top:1.5vh;font-size:13vh;font-weight:900;line-height:1;text-shadow:0 .5vh 1vh rgba(0,0,0,.4)}
    #tiaMini{position:absolute;left:3vw;top:1vh;width:15vh;height:15vh}
    #message{position:absolute;left:0;right:0;top:2.5vh;text-align:center;font-size:7vh;font-weight:800;color:#FFC845;text-shadow:0 .4vh 1vh rgba(0,0,0,.6)}
    #message.pill{left:2vw;right:auto;text-align:left;padding:1.2vh 2.4vw;border-radius:5vh;background:rgba(0,0,0,.6)}
    #cam{position:absolute;display:none;background:#000}
    #stage{position:absolute;left:0;top:17vh;width:100%;height:74vh;display:none}
    #card{position:absolute;right:2vw;top:2vh;width:24vh;padding:1.4vh;border-radius:2vh;border:.5vh solid #fff;text-align:center;display:none;box-shadow:0 1vh 3vh rgba(0,0,0,.6)}
    #cardWord{font-size:5.4vh;font-weight:900}
    #tiaCard{width:16vh;height:16vh;margin:0 auto}
    #cardTag{font-size:3vh;font-weight:700;min-height:3.4vh}
    #note{position:absolute;left:2vw;bottom:9vh;font-size:3vh;color:rgba(255,255,255,.85);background:rgba(0,0,0,.5);padding:.6vh 1.4vw;border-radius:1vh;display:none}
    #players{position:absolute;left:0;right:0;bottom:1vh;text-align:center}
    .chip{display:inline-block;margin:.4vh .8vw;padding:.8vh 1.6vw;border-radius:6vh;background:rgba(0,0,0,.45);font-size:3.8vh}
    .chip.out{opacity:.4}
    .dot{display:inline-block;width:3vh;height:3vh;border-radius:50%;margin-right:.8vw;vertical-align:middle}
    #status{position:absolute;right:2vw;bottom:9vh;font-size:2.6vh;opacity:.8}
    #sound{position:absolute;left:0;right:0;bottom:0;padding:2vh;text-align:center;font-size:3.4vh;background:#FFC845;color:#1B1433;font-weight:700}

    /* ---- efeito relâmpago */
    #hero{position:absolute;left:0;top:0;right:0;bottom:0;display:none;pointer-events:none}
    #heroWord{position:absolute;left:0;right:0;top:50%;margin-top:-20vh;text-align:center;font-size:34vh;font-weight:900;line-height:1;color:#fff;
      text-shadow:0 0 3vh #fff,0 0 9vh #FFF176,0 1.2vh 2.4vh rgba(0,0,0,.55)}
    #heroWord.small{font-size:22vh;margin-top:-13vh}
    .bolt{position:absolute;top:3vh;height:94vh;opacity:0;-webkit-filter:drop-shadow(0 0 3vh #FFF176);filter:drop-shadow(0 0 3vh #FFF176)}
    #boltL{left:4vw}
    #boltR{right:4vw}
    #flash{position:absolute;left:0;top:0;right:0;bottom:0;background:#fff;opacity:0;pointer-events:none}
    @-webkit-keyframes flashA{0%{opacity:.95}100%{opacity:0}}
    @keyframes flashA{0%{opacity:.95}100%{opacity:0}}
    @-webkit-keyframes slamA{0%{-webkit-transform:scale(2.8);opacity:0}16%{-webkit-transform:scale(1);opacity:1}70%{-webkit-transform:scale(1.07);opacity:1}100%{-webkit-transform:scale(.55);opacity:0}}
    @keyframes slamA{0%{transform:scale(2.8);opacity:0}16%{transform:scale(1);opacity:1}70%{transform:scale(1.07);opacity:1}100%{transform:scale(.55);opacity:0}}
    @-webkit-keyframes boltA{0%{opacity:0;-webkit-transform:scale(.6)}14%{opacity:1;-webkit-transform:scale(1.08)}100%{opacity:0;-webkit-transform:scale(1.25)}}
    @keyframes boltA{0%{opacity:0;transform:scale(.6)}14%{opacity:1;transform:scale(1.08)}100%{opacity:0;transform:scale(1.25)}}
    @-webkit-keyframes boltRA{0%{opacity:0;-webkit-transform:scaleX(-.6) scaleY(.6)}14%{opacity:1;-webkit-transform:scaleX(-1.08) scaleY(1.08)}100%{opacity:0;-webkit-transform:scaleX(-1.25) scaleY(1.25)}}
    @keyframes boltRA{0%{opacity:0;transform:scaleX(-.6) scaleY(.6)}14%{opacity:1;transform:scaleX(-1.08) scaleY(1.08)}100%{opacity:0;transform:scaleX(-1.25) scaleY(1.25)}}
    @-webkit-keyframes popA{0%{-webkit-transform:scale(.3);opacity:0}35%{-webkit-transform:scale(1.25);opacity:1}100%{-webkit-transform:scale(1);opacity:1}}
    @keyframes popA{0%{transform:scale(.3);opacity:0}35%{transform:scale(1.25);opacity:1}100%{transform:scale(1);opacity:1}}
    .flashing{-webkit-animation:flashA .55s ease-out;animation:flashA .55s ease-out}
    .slam{-webkit-animation:slamA 1s ease-out forwards;animation:slamA 1s ease-out forwards}
    .popin{-webkit-animation:popA .8s ease-out forwards;animation:popA .8s ease-out forwards}
    #boltL.go{-webkit-animation:boltA .8s ease-out forwards;animation:boltA .8s ease-out forwards}
    #boltR.go{-webkit-animation:boltRA .8s ease-out forwards;animation:boltRA .8s ease-out forwards}
    #word.arrive{-webkit-animation:popA .4s .7s ease-out both;animation:popA .4s .7s ease-out both}
    </style>
    </head>
    <body>
    <div id="bg"></div>
    <video id="replay" muted loop autoplay playsinline></video>
    <div id="top"><div id="tiaMini"></div><div id="word"></div></div>
    <div id="message"></div>
    <img id="cam" alt="">
    <canvas id="stage"></canvas>
    <div id="card"><div id="cardWord"></div><div id="tiaCard"></div><div id="cardTag"></div></div>
    <div id="note"></div>
    <div id="players"></div>
    <div id="flash"></div>
    <div id="hero">
      <svg id="boltL" class="bolt" viewBox="0 0 100 200"><polygon points="62,0 14,108 46,108 28,200 86,76 52,76 74,0" fill="#FFF176" stroke="#fff" stroke-width="3" stroke-linejoin="round"/></svg>
      <svg id="boltR" class="bolt" viewBox="0 0 100 200"><polygon points="62,0 14,108 46,108 28,200 86,76 52,76 74,0" fill="#FFF176" stroke="#fff" stroke-width="3" stroke-linejoin="round"/></svg>
      <div id="heroWord"></div>
    </div>
    <div id="status">Conectando…</div>
    <div id="sound">Aperte OK (ou qualquer tecla) no controle para ligar o som</div>
    <script>
    var unlocked = false, ctx = null, buffers = {}, pending = {}, active = [], epoch = 0;
    var fallback = null, total = 0, loaded = 0;
    var lastState = { screen: 'menu', players: [] }, lastPose = { figures: [] };
    var lastCommand = null, lastBanner = null;
    var camCode = (location.search.match(/[?&]t=([0-9]+)/) || [])[1];
    function el(id){ return document.getElementById(id); }

    // ---------- tia (a mesma em dois tamanhos)
    function tiaSvg(p){
      return '<svg viewBox="0 0 200 200" style="width:100%;height:100%">'
        + '<line id="' + p + 'L" x1="70" y1="100" x2="70" y2="165" stroke="#FFD9B8" stroke-width="16" stroke-linecap="round"/>'
        + '<line id="' + p + 'R" x1="130" y1="100" x2="130" y2="165" stroke="#FFD9B8" stroke-width="16" stroke-linecap="round"/>'
        + '<rect x="55" y="82" width="90" height="100" rx="26" fill="#8E7BFF"/>'
        + '<circle cx="100" cy="52" r="34" fill="#FFD9B8"/>'
        + '<circle cx="88" cy="48" r="4" fill="#000"/><circle cx="112" cy="48" r="4" fill="#000"/>'
        + '<path d="M86 64 Q100 76 114 64" stroke="#000" stroke-width="4" fill="none" stroke-linecap="round"/></svg>';
    }
    function setArms(g){
      var up = (g === 'up'), l = up ? 150 : 18, r = up ? -150 : -18, ids = ['m', 'c'];
      for (var i = 0; i < ids.length; i++) {
        el(ids[i] + 'L').setAttribute('transform', 'rotate(' + l + ' 70 100)');
        el(ids[i] + 'R').setAttribute('transform', 'rotate(' + r + ' 130 100)');
      }
    }

    // ---------- avatares (desenhados a partir das juntas do corpo, nunca da imagem)
    function shade(hex, f){
      var n = parseInt(hex.replace('#', ''), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
      return 'rgb(' + Math.round(r * f) + ',' + Math.round(g * f) + ',' + Math.round(b * f) + ')';
    }
    function mid(a, b){ return (a && b) ? [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2] : (a || b); }
    function dot(g, p, r, color){ if (!p) return; g.fillStyle = color; g.beginPath(); g.arc(p[0], p[1], r, 0, 6.2832); g.fill(); }
    function limb(g, a, b, w, color){
      if (!a || !b) return;
      g.strokeStyle = color; g.lineWidth = w; g.lineCap = 'round';
      g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
    }
    function drawAvatar(g, f, ox, oy, bw, bh){
      function P(k){ var p = f.joints[k]; return p ? [ox + p[0] * bw, oy + p[1] * bh] : null; }
      var ls = P('ls'), rs = P('rs'), lh = P('lh'), rh = P('rh'), nose = P('n');
      var u = (ls && rs) ? Math.abs(ls[0] - rs[0]) : ((lh && rh) ? Math.abs(lh[0] - rh[0]) * 1.2 : bh * 0.08);
      u = Math.max(bh * 0.045, Math.min(bh * 0.22, u));
      var body = f.color, dark = shade(f.color, 0.6), skin = '#FFD9B8';
      g.globalAlpha = f.ready ? 1 : 0.6;
      limb(g, lh, P('lk'), u * 0.5, dark); limb(g, P('lk'), P('la'), u * 0.5, dark);
      limb(g, rh, P('rk'), u * 0.5, dark); limb(g, P('rk'), P('ra'), u * 0.5, dark);
      dot(g, P('la'), u * 0.32, '#2b2140'); dot(g, P('ra'), u * 0.32, '#2b2140');
      var ms = mid(ls, rs), mh = mid(lh, rh);
      if (ms && mh) { limb(g, ms, mh, u * 1.2, body); }
      else if (ms) { limb(g, ms, [ms[0], ms[1] + u * 1.7], u * 1.2, body); }
      limb(g, ls, P('le'), u * 0.42, body); limb(g, P('le'), P('lw'), u * 0.4, body);
      limb(g, rs, P('re'), u * 0.42, body); limb(g, P('re'), P('rw'), u * 0.4, body);
      dot(g, P('lw'), u * 0.27, skin); dot(g, P('rw'), u * 0.27, skin);
      if (nose) {
        var r = u * 0.66;
        dot(g, nose, r, skin);
        g.fillStyle = dark; g.beginPath(); g.arc(nose[0], nose[1], r * 1.04, 3.3, 6.12); g.fill();
        dot(g, [nose[0] - r * 0.36, nose[1] - r * 0.02], r * 0.11, '#000');
        dot(g, [nose[0] + r * 0.36, nose[1] - r * 0.02], r * 0.11, '#000');
        g.strokeStyle = '#000'; g.lineWidth = Math.max(2, r * 0.1); g.lineCap = 'round';
        g.beginPath(); g.arc(nose[0], nose[1] + r * 0.12, r * 0.38, 0.35, 2.79); g.stroke();
        g.fillStyle = '#fff'; g.strokeStyle = 'rgba(0,0,0,0.7)'; g.lineWidth = 5; g.textAlign = 'center';
        g.font = 'bold ' + Math.round(bh * 0.07) + 'px Arial';
        var label = f.name + (f.ready ? ' ✓' : ' !'), ly = Math.max(oy + bh * 0.08, nose[1] - r * 1.5);
        g.strokeText(label, nose[0], ly); g.fillText(label, nose[0], ly);
      }
      g.globalAlpha = 1;
    }
    function stageBox(c){
      var W = c.width = c.clientWidth, H = c.height = c.clientHeight, aspect = lastPose.aspect || 1.7778;
      var bw = W, bh = W / aspect;
      if (bh > H) { bh = H; bw = H * aspect; }
      return { W: W, H: H, ox: (W - bw) / 2, oy: (H - bh) / 2, bw: bw, bh: bh };
    }
    function drawStage(){
      var c = el('stage');
      if (!c.getContext || c.style.display === 'none') return;
      var g = c.getContext('2d'), b = stageBox(c);
      g.clearRect(0, 0, b.W, b.H);
      var cam = el('cam');
      if (cam.style.display === 'block') {
        cam.style.left = (c.offsetLeft + b.ox) + 'px'; cam.style.top = (c.offsetTop + b.oy) + 'px';
        cam.style.width = b.bw + 'px'; cam.style.height = b.bh + 'px';
      } else {
        g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(b.ox, b.oy, b.bw, b.bh);
      }
      g.strokeStyle = 'rgba(255,255,255,0.35)'; g.lineWidth = 3; g.strokeRect(b.ox, b.oy, b.bw, b.bh);
      var figs = lastPose.figures || [];
      for (var i = 0; i < figs.length; i++) { drawAvatar(g, figs[i], b.ox, b.oy, b.bw, b.bh); }
    }

    // ---------- efeito relâmpago (comando) e destaque (contagem e avisos)
    function restart(node, cls){
      // getAttribute/setAttribute funcionam também em elementos SVG (onde className não é um texto).
      var kept = (node.getAttribute('class') || '').replace(cls, '').replace(/^\s+|\s+$/g, '');
      node.setAttribute('class', kept);
      void node.getBoundingClientRect();
      node.setAttribute('class', kept ? kept + ' ' + cls : cls);
    }
    function lightning(text){
      var hero = el('hero');
      hero.style.display = 'block';
      el('heroWord').textContent = text;
      el('heroWord').className = '';
      restart(el('heroWord'), 'slam'); restart(el('boltL'), 'go'); restart(el('boltR'), 'go'); restart(el('flash'), 'flashing');
      restart(el('word'), 'arrive');
      setTimeout(function(){ hero.style.display = 'none'; }, 1050);
    }
    function announce(text){
      var hero = el('hero');
      hero.style.display = 'block';
      el('heroWord').textContent = text;
      el('heroWord').className = (text.length > 3 ? 'small' : '');
      restart(el('heroWord'), 'popin');
      if (text.length > 3) { restart(el('boltL'), 'go'); restart(el('boltR'), 'go'); }
      setTimeout(function(){ hero.style.display = 'none'; }, 900);
    }

    // ---------- tela
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
      var positioning = (s.screen === 'positioning');
      var playing = (s.screen === 'play');
      var result = (s.screen === 'result');
      var video = showReplay(s);
      var stage = el('stage'), cam = el('cam'), card = el('card');
      el('bg').style.background = (s.word && s.background) ? s.background : 'linear-gradient(#1B1433,#3A2A6B)';
      el('word').textContent = (playing && s.word) ? s.word : '';
      el('top').style.display = (playing || (result && !video)) ? 'block' : 'none';
      el('tiaMini').style.display = (playing || result) ? 'block' : 'none';
      el('message').className = video ? 'pill' : '';
      el('message').textContent = positioning ? (s.banner || '') : (s.message || (s.screen === 'menu' ? 'Agacha!' : ''));
      stage.style.display = ((positioning || playing || result) && !video) ? 'block' : 'none';
      stage.style.top = positioning ? '14vh' : '17vh';
      stage.style.height = positioning ? '77vh' : '74vh';
      var showCam = positioning && camCode;
      if (showCam && !cam.getAttribute('data-on')) { cam.src = '/camera.mjpg?t=' + camCode; cam.setAttribute('data-on', '1'); }
      cam.style.display = (showCam && !video) ? 'block' : 'none';
      card.style.display = (result && s.word) ? 'block' : 'none';
      card.style.background = s.background || '#333';
      el('cardWord').textContent = s.word || '';
      el('cardTag').textContent = s.trick ? 'Truque!' : '';
      el('note').style.display = (result && s.note) ? 'block' : 'none';
      el('note').textContent = s.note || '';
      setArms((playing || result) ? s.gesture : null);
      var html = '';
      for (var i = 0; i < (s.players || []).length; i++) {
        var p = s.players[i];
        html += '<span class="chip' + (p.out ? ' out' : '') + '"><span class="dot" style="background:' + p.color + '"></span>'
              + p.name.replace(/</g, '&lt;') + (p.detail ? ' ' + p.detail : '') + '</span>';
      }
      el('players').innerHTML = html;
      if (playing && s.word && s.command !== lastCommand) { lastCommand = s.command; lightning(s.word); }
      if (!s.word) { lastCommand = null; }
      if (playing && !s.word && s.banner && s.banner !== lastBanner) { lastBanner = s.banner; announce(s.banner); }
      if (!s.banner) { lastBanner = null; }
      drawStage();
    }
    function pose(p){ lastPose = p; drawStage(); }

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
    el('tiaMini').innerHTML = tiaSvg('m');
    el('tiaCard').innerHTML = tiaSvg('c');
    setArms(null);
    connect();
    </script>
    </body>
    </html>
    """#
}
// swiftlint:enable line_length type_body_length
