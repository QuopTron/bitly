// ─────────────────────────────────────────────────────────────
// panel_verificacion_branding_js.dart — PART de
// panel_verificacion_web.dart: JS que re-marca la página del captcha
// a Bitly — nodos de texto, título, atributos visibles y paleta de
// color del challenge — para que el sandbox muestre Bitly arriba
// mientras sigue siendo la página Cloudflare de SpotiFLAC debajo.
// El widget Turnstile vive en un iframe y el puente `SpotiflacGrant`
// es JS (no texto DOM), así ambos quedan intactos.
// Se conecta con: panel_verificacion_web.dart (misma library).
// Parte del flujo: verificación de sesiones (branding del captcha).
// ─────────────────────────────────────────────────────────────

part of 'panel_verificacion_web.dart';

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
