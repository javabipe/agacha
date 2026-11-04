// Página da TV: ES5 puro (navegadores de TV antigos). Mostra um código, espera o iPad e vai para o jogo na rede da casa.
(function () {
  var sessionId = null;
  function el(id) { return document.getElementById(id); }

  function request(method, url, body, done) {
    var x = new XMLHttpRequest();
    x.open(method, url, true);
    x.timeout = 35000;
    x.setRequestHeader('Content-Type', 'application/json');
    x.onreadystatechange = function () {
      if (x.readyState !== 4) { return; }
      var data = null;
      try { data = JSON.parse(x.responseText); } catch (e) { data = null; }
      done(x.status, data);
    };
    x.send(body ? JSON.stringify(body) : null);
  }

  function go(url) {
    el('status').textContent = 'Conectando ao jogo…';
    if (typeof url === 'string' && url.indexOf('http://') === 0) { window.location.href = url; }
  }

  function start() {
    request('POST', '/api/tv/session', null, function (status, data) {
      if (status === 200 && data && data.session) {
        sessionId = data.session;
        el('code').textContent = data.code;
        el('status').textContent = 'Esperando o iPad…';
        poll();
      } else {
        el('status').textContent = status === 429 ? 'Muitas tentativas. Espere um pouco…' : 'Sem conexão. Tentando de novo…';
        setTimeout(start, 4000);
      }
    });
  }

  function poll() {
    if (!sessionId) { return; }
    request('GET', '/api/tv/wait?s=' + sessionId, null, function (status, data) {
      if (status === 200 && data && data.status === 'paired') { go(data.url); }
      else if (status === 200 && data && data.status === 'waiting') { poll(); }
      else if (status === 404) { start(); }
      else { setTimeout(poll, 3000); }
    });
  }

  el('claimForm').onsubmit = function () {
    var code = el('claimCode').value;
    if (!/^[0-9]{4}$/.test(code)) { el('status').textContent = 'O código tem 4 números.'; return false; }
    request('POST', '/api/tv/claim', { code: code }, function (status, data) {
      if (status === 200 && data && data.url) { go(data.url); }
      else if (status === 429) { el('status').textContent = 'Muitas tentativas. Espere um pouco…'; }
      else { el('status').textContent = 'Código não encontrado. Confira no iPad.'; }
    });
    return false;
  };

  start();
}());
