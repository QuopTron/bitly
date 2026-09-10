// ─────────────────────────────────────────────────────────────
// panel_verificacion_branding.dart — PART de
// panel_verificacion_web.dart: scripts JS inyectados en la página
// del captcha (servida por zarz.moe, que no controlamos).
//
// 1) `_jsInterceptorGrant`: hookea `fetch` y `XMLHttpRequest` para
//    rescatar el grant de la respuesta de verificación y entregarlo
//    por el puente `SpotiflacGrant`. Es la red de seguridad
//    multiplataforma: aunque la página no notifique el callback,
//    el grant igual vuelve a Flutter. Se inyecta en onPageStarted
//    y onPageFinished (idempotente).
// 2) `_jsBrandingBitly`: reemplaza TODA ocurrencia "SpotiFLAC"/
//    "spotiflac" con "bitly" — nodos de texto, chrome de nav,
//    título y atributos visibles — para que el sandbox muestre
//    Bitly arriba mientras sigue siendo la página Cloudflare de
//    SpotiFLAC debajo. El widget Turnstile vive en un iframe y el
//    puente `SpotiflacGrant` es JS (no texto DOM), así ambos
//    quedan intactos y la verificación sigue funcionando.
// Se conecta con: panel_verificacion_web.dart (misma library).
// Parte del flujo: verificación de sesiones (branding del captcha).
// ─────────────────────────────────────────────────────────────

part of 'panel_verificacion_web.dart';

/// JS que rescata el grant de la respuesta de verificación de zarz y lo
/// entrega por el puente `SpotiflacGrant`. La página completa el Turnstile y
/// hace fetch('/v2/challenge/verify'); la respuesta trae el grant. En Windows
/// (webview_win_floating / WebView2) el post del canal puede no llegar o la
/// navegación al callback local puede ser bloqueada, así que este interceptor
/// captura el grant DIRECTAMENTE de la respuesta (fetch o XHR), sin depender
/// de la navegación. Es idempotente (`window.__spotiflacGrantHooked`).
const _jsInterceptorGrant = r'''
  (function(){
    try {
      if (window.__spotiflacGrantHooked) return;
      window.__spotiflacGrantHooked = true;

      function entregar(g){
        if (!g || typeof g !== 'string' || g.length < 5) return;
        try {
          if (window.SpotiflacGrant &&
              typeof window.SpotiflacGrant.postMessage === 'function') {
            window.SpotiflacGrant.postMessage(g);
          } else if (window.chrome && window.chrome.webview &&
                     window.chrome.webview.postMessage) {
            window.chrome.webview.postMessage(
              { 'JkChannelName': 'SpotiflacGrant', 'msg': g });
          }
        } catch(e) {}
      }

      function extraer(txt){
        if (!txt) return null;
        try {
          var j = JSON.parse(txt);
          var g = j && (j.grant || j.code || j.token ||
            (j.data && (j.data.grant || j.data.code || j.data.token)));
          if (typeof g === 'string' && g.length > 5) return g;
        } catch(e) {}
        var m = String(txt).match(/[?&](?:grant|code|token)=([^&\s"']+)/);
        if (m && m[1]) {
          try { return decodeURIComponent(m[1]); } catch(e) { return m[1]; }
        }
        var t = String(txt).match(/gr_[A-Za-z0-9_\-]+/);
        if (t) return t[0];
        return null;
      }

      var relevante = /challenge\/verify|session|grant|exchange/i;

      var origFetch = window.fetch;
      if (typeof origFetch === 'function') {
        window.fetch = function(){
          var args = arguments;
          var p = origFetch.apply(this, args);
          try {
            p.then(function(res){
              try {
                var u = (typeof args[0] === 'string')
                  ? args[0]
                  : ((args[0] && args[0].url) || '');
                if (relevante.test(u)) {
                  res.clone().text().then(function(t){ entregar(extraer(t)); });
                }
              } catch(e) {}
            });
          } catch(e) {}
          return p;
        };
      }

      if (window.XMLHttpRequest && XMLHttpRequest.prototype) {
        var abrirOrig = XMLHttpRequest.prototype.open;
        var enviarOrig = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url){
          this.__urlBitly = url;
          return abrirOrig.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function(){
          var xhr = this;
          try {
            xhr.addEventListener('load', function(){
              try {
                if (relevante.test(xhr.__urlBitly || '')) {
                  entregar(extraer(xhr.responseText));
                }
              } catch(e) {}
            });
          } catch(e) {}
          return enviarOrig.apply(this, arguments);
        };
      }
    } catch(e) {}
  })();
''';

/// JS que re-marca la página del captcha a Bitly (texto, título, atributos
/// visibles y paleta de color del challenge).
const _jsBrandingBitly = r'''
  (function(){
    function rebrand(){
      try {
        document.title = document.title.replace(/spotiflac/gi, 'bitly');
        // 1) Reemplazar la marca en cada nodo de texto (chrome, footer,
        //    headings, botones — cualquier cosa visible).
        var walker = document.createTreeWalker(
          document.body, NodeFilter.SHOW_TEXT, null, false);
        var nodes = [];
        while (walker.nextNode()) nodes.push(walker.currentNode);
        for (var i = 0; i < nodes.length; i++) {
          var t = nodes[i].nodeValue;
          if (t && /spotiflac/i.test(t)) {
            nodes[i].nodeValue = t.replace(/spotiflac/gi, 'bitly');
          }
        }
        // 2) Fallback para la marca de nav si no fue cubierta arriba.
        var nav = document.querySelector('.nav-brand');
        if (nav) {
          var spans = nav.querySelectorAll('span');
          for (var j = 0; j < spans.length; j++) {
            if (spans[j] && /spotiflac/i.test(spans[j].textContent || '')) {
              spans[j].textContent =
                spans[j].textContent.replace(/spotiflac/gi, 'bitly');
            }
          }
        }
        // 3) Atributos visibles que pueden llevar el nombre del proveedor.
        var attrs = ['aria-label', 'alt', 'placeholder', 'title'];
        var all = document.querySelectorAll('*');
        for (var k = 0; k < all.length; k++) {
          for (var a = 0; a < attrs.length; a++) {
            var v = all[k].getAttribute(attrs[a]);
            if (v && /spotiflac/i.test(v)) {
              all[k].setAttribute(attrs[a], v.replace(/spotiflac/gi, 'bitly'));
            }
          }
        }
        // Re-mapear la paleta del challenge al verde neón + casi negro.
        var root = document.documentElement;
        if (root) {
          root.style.setProperty('--green', '#5AF13D');
          root.style.setProperty('--green-dim', '#3FEF38');
          root.style.setProperty('--bg', '#000000');
          root.style.setProperty('--surface', '#1A1A1A');
          root.style.setProperty('--card', '#1A1A1A');
          root.style.setProperty('--card-hover', '#222222');
          root.style.setProperty('--text', '#ffffff');
        }
      } catch(e) {}
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', rebrand);
    } else {
      rebrand();
    }
  })();
''';
