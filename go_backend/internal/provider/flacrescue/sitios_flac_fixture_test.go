// ─────────────────────────────────────────────────────────────
// sitios_flac_fixture_test.go — Recorte REAL de la página de búsqueda de
// superflac, compartido por los tests del canal de sitios raspables (ver
// sitios_flac_test.go). Guardarlo acá mantiene cada archivo por debajo del
// tope de líneas y deja el HTML en un solo lugar.
// ─────────────────────────────────────────────────────────────

package flacrescue

// htmlBusqueda es un recorte real de la búsqueda del sitio: el primer
// resultado es la canción pedida y los demás son ruido de la búsqueda por
// texto (lo que aparece cuando el ISRC no existe en ese catálogo).
const htmlBusqueda = `<div id="search-page">
  <form class="result-item result-track">
    <input type="hidden" name="_token" value="tok-nuevayol">
    <input type="hidden" name="music_url" value="https://open.qobuz.com/track/312055179">
    <input type="hidden" name="resource_kind" value="track">
    <div class="result-item__info track-info">
      <div class="result-item__title">
        <span class="result-item__name">NUEVAYoL</span>
        <span class="result-badge result-badge--source">[QOBUZ]</span>
      </div>
      <div class="result-item__sub">Bad Bunny - DeBÍ TiRAR MáS FOToS - 3:03</div>
    </div>
    <div class="track-actions">
      <select class="select select-inline" name="quality">
        <option value="FLAC_HIRES">[ FLAC Hi-Res ]</option>
        <option value="FLAC">[ FLAC Lossless ]</option>
        <option value="MP3_320">[ MP3 320 kbps ]</option>
      </select>
    </div>
  </form>
  <form class="result-item result-track">
    <input type="hidden" name="_token" value="tok-basura">
    <input type="hidden" name="music_url" value="https://tidal.com/track/435002737">
    <input type="hidden" name="resource_kind" value="track">
    <div class="result-item__info track-info">
      <div class="result-item__title"><span class="result-item__name">Perfect tuning</span></div>
      <div class="result-item__sub">Eirlys - Unaccompanied stories - 1:50</div>
    </div>
    <div class="track-actions">
      <select class="select select-inline" name="quality"><option value="FLAC">[ FLAC ]</option></select>
    </div>
  </form>
  <form class="result-item result-track">
    <input type="hidden" name="_token" value="tok-video">
    <input type="hidden" name="music_url" value="https://www.youtube.com/watch?v=Jg4bxoyywyA">
    <input type="hidden" name="resource_kind" value="track">
    <div class="result-item__info track-info">
      <div class="result-item__title"><span class="result-item__name">Cut To The Feeling</span></div>
      <div class="result-item__sub">Carly Rae Jepsen - YouTube Video - 3:28</div>
    </div>
    <div class="track-actions">
      <select class="select select-inline" name="quality"><option value="MP3_320">[ MP3 320 ]</option></select>
    </div>
  </form>
</div>`
