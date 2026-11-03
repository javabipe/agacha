// swiftlint:disable line_length
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
    #center{position:absolute;left:0;right:0;top:0;bottom:20vh;display:flex;align-items:center;justify-content:center}
    #tia{width:36vh;height:36vh;margin-right:4vw;display:none}
    #word{font-size:26vh;font-weight:900;text-align:center;text-shadow:0 .6vh 1.2vh rgba(0,0,0,.4)}
    #banner{font-size:11vh;font-weight:800;text-align:center;padding:0 4vw;line-height:1.1}
    #message{position:absolute;left:0;right:0;top:3vh;text-align:center;font-size:8vh;font-weight:800;color:#FFC845}
    #players{position:absolute;left:0;right:0;bottom:3vh;text-align:center}
    .chip{display:inline-block;margin:.6vh 1vw;padding:1.2vh 2vw;border-radius:6vh;background:rgba(0,0,0,.4);font-size:4.6vh}
    .chip.out{opacity:.4}
    .dot{display:inline-block;width:3.4vh;height:3.4vh;border-radius:50%;margin-right:1vw;vertical-align:middle}
    #status{position:absolute;right:2vw;top:2vh;font-size:2.6vh;opacity:.8}
    #sound{position:absolute;left:0;right:0;bottom:0;padding:2vh;text-align:center;font-size:3.4vh;background:#FFC845;color:#1B1433;font-weight:700}
    </style>
    </head>
    <body>
    <div id="bg"></div>
    <div id="message"></div>
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
    <div id="players"></div>
    <div id="status">Conectando…</div>
    <div id="sound">Aperte OK (ou qualquer tecla) no controle para ligar o som</div>
    <script>
    var unlocked = false, current = [], cache = {};
    function el(id){ return document.getElementById(id); }
    function setArms(g){
      var up = (g === 'up'), l = up ? 150 : 18, r = up ? -150 : -18;
      el('armL').setAttribute('transform', 'rotate(' + l + ' 70 100)');
      el('armR').setAttribute('transform', 'rotate(' + r + ' 130 100)');
    }
    function render(s){
      var play = (s.screen === 'play' && s.word);
      el('bg').style.background = (s.word && s.background) ? s.background : 'linear-gradient(#1B1433,#3A2A6B)';
      el('word').textContent = s.word || '';
      el('banner').textContent = s.banner || (s.screen === 'menu' ? 'Agacha!' : '');
      el('message').textContent = s.message || '';
      el('tia').style.display = (s.screen === 'play' || s.screen === 'result') ? 'block' : 'none';
      setArms(play ? s.gesture : null);
      var html = '';
      for (var i = 0; i < (s.players || []).length; i++) {
        var p = s.players[i];
        html += '<span class="chip' + (p.out ? ' out' : '') + '"><span class="dot" style="background:' + p.color + '"></span>'
              + p.name.replace(/</g, '&lt;') + (p.detail ? ' ' + p.detail : '') + '</span>';
      }
      el('players').innerHTML = html;
    }
    function stopAll(){
      for (var i = 0; i < current.length; i++) { try { current[i].pause(); } catch (e) {} }
      current = [];
      if (window.speechSynthesis) { try { window.speechSynthesis.cancel(); } catch (e) {} }
    }
    function playClip(name){
      if (!unlocked) return;
      var a = cache[name] || new Audio('/audio/' + name + '.wav');
      cache[name] = a;
      try { a.currentTime = 0; } catch (e) {}
      current.push(a);
      var p = a.play(); if (p && p.catch) p.catch(function(){});
    }
    function say(text){
      if (!unlocked || !window.speechSynthesis) return;
      try { var u = new SpeechSynthesisUtterance(text); u.lang = 'pt-BR'; window.speechSynthesis.speak(u); } catch (e) {}
    }
    function unlock(){
      if (unlocked) return;
      unlocked = true;
      el('sound').style.display = 'none';
      var x = new XMLHttpRequest();
      x.open('GET', '/clips');
      x.onload = function(){
        try { var names = JSON.parse(x.responseText); for (var i = 0; i < names.length; i++) {
          var a = new Audio('/audio/' + names[i] + '.wav'); a.preload = 'auto'; cache[names[i]] = a; } } catch (e) {}
      };
      x.send();
    }
    document.addEventListener('keydown', unlock);
    document.addEventListener('click', unlock);
    document.addEventListener('touchstart', unlock);
    function connect(){
      var es = new EventSource('/events');
      es.addEventListener('state', function(e){ el('status').textContent = ''; render(JSON.parse(e.data)); });
      es.addEventListener('audio', function(e){ playClip(e.data); });
      es.addEventListener('say', function(e){ say(e.data); });
      es.addEventListener('stop', stopAll);
      es.onerror = function(){ el('status').textContent = 'Reconectando…'; };
    }
    setArms(null);
    connect();
    </script>
    </body>
    </html>
    """#
}
// swiftlint:enable line_length
