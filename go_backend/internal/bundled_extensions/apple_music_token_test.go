// apple_music_token_test.go — Guardas del raspado y la verificación del
// developer token de apple-music.
//
// Qué se está cuidando: el catalog API exige un developer token JWT. El raspado
// original adoptaba el primer JWT que encontrara sin comprobar NADA. Eso rompe
// de dos maneras medibles: (1) el bundle del web player trae VARIOS JWT —el del
// web player, con kid:WebPlayKid, y otros internos con kids distintos
// (LT2ZDZSNNQ, 97DQU9QUD6)—, y quedarse con el equivocado da 401 en cada
// llamada; (2) un token ya vencido se cachea y se PERSISTE, así que el error se
// repite en cada arranque sin que el rescate vuelva a intentar. Verificar ANTES
// de adoptar convierte ese fallo silencioso en un rechazo inmediato que deja
// probar la fuente siguiente.
//
// Dos capas, cada una por una razón distinta:
//
//  1. TestAppleMusicConservaLaVerificacionDelToken — guarda de TEXTO. Evita el
//     borrado silencioso de las piezas que costó medir (la verificación, el kid
//     correcto, la exp, MusicKit probado antes que los bundles). Falla diciendo
//     qué se pierde.
//  2. TestAppleMusicVerificaElTokenAntesDeAdoptarlo — FUNCIONAL con Node, sin
//     red: ejecuta el JS real contra tokens fabricados (bueno, de otro kid, de
//     otro alg, vencido, sin exp, basura) y exige que solo pase el bueno.
package bundled_extensions

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestAppleMusicConservaLaVerificacionDelToken(t *testing.T) {
	codigo := leerExtension(t, "apple-music")

	piezas := []struct {
		nombre string
		marca  string
		porQue string
	}{
		{
			nombre: "verificación previa a la adopción",
			marca:  "verificarJWTApple",
			porQue: "sin esto se adopta cualquier JWT que aparezca, incluido uno de otro kid o ya vencido, y el 401 se cachea",
		},
		{
			nombre: "exigencia del kid del web player",
			marca:  "WebPlayKid",
			porQue: "el bundle trae otros JWT con kids internos; adoptarlos da 401 en cada llamada",
		},
		{
			nombre: "exigencia de exp futura",
			marca:  "carga.exp",
			porQue: "un token vencido se persistiría y el arranque siguiente lo reusaría roto",
		},
		{
			nombre: "adopción guardada",
			marca:  "adoptarTokenApple",
			porQue: "es el único punto que fija state.token; si se lo salta la verificación, la verificación deja de servir",
		},
		{
			nombre: "MusicKit como fuente estable",
			marca:  "MUSICKIT_URLS",
			porQue: "musickit.js no lleva hash en el nombre, a diferencia de /assets/index~<hash>.js que rota",
		},
		{
			nombre: "MusicKit probado antes que los bundles",
			marca:  "buscarTokenEnMusickit",
			porQue: "el orden pedido: SDK estable primero, bundles rotativos después",
		},
	}
	for _, p := range piezas {
		if !strings.Contains(codigo, p.marca) {
			t.Errorf("falta %s (%s): %s", p.nombre, p.marca, p.porQue)
		}
	}

	// El raspado ciego viejo usaba extractJWTFromString (primer candidato sin
	// verificar). Si vuelve, es que se revirtió el endurecimiento.
	if strings.Contains(codigo, "extractJWTFromString") {
		t.Error("volvió extractJWTFromString: adopta el primer JWT sin verificar kid/alg/exp")
	}
}

// guionAppleToken fabrica tokens y consulta la verificación real de la extensión.
// Usa Buffer (Node) para el base64url; el JS de la extensión define su propio
// atob, así que no hay choque.
const guionAppleToken = `
function b64u(obj) {
  var s = Buffer.from(JSON.stringify(obj), "binary").toString("base64");
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function mk(h, p) {
  return b64u(h) + "." + b64u(p) + ".AAAA";
}
var futuro = Math.floor(Date.now() / 1000) + 3600;
var pasado = Math.floor(Date.now() / 1000) - 3600;
var bueno = mk({ typ: "JWT", alg: "ES256", kid: "WebPlayKid" }, { iss: "AMPWebPlay", exp: futuro });
var otroKid = mk({ typ: "JWT", alg: "ES256", kid: "LT2ZDZSNNQ" }, { iss: "OTRO", exp: futuro });
var otroAlg = mk({ typ: "JWT", alg: "HS256", kid: "WebPlayKid" }, { iss: "AMPWebPlay", exp: futuro });
var vencido = mk({ typ: "JWT", alg: "ES256", kid: "WebPlayKid" }, { iss: "AMPWebPlay", exp: pasado });
var sinExp = mk({ typ: "JWT", alg: "ES256", kid: "WebPlayKid" }, { iss: "AMPWebPlay" });
var salida = {
  bueno: !!verificarJWTApple(bueno),
  otroKid: !!verificarJWTApple(otroKid),
  otroAlg: !!verificarJWTApple(otroAlg),
  vencido: !!verificarJWTApple(vencido),
  sinExp: !!verificarJWTApple(sinExp),
  basura: !!verificarJWTApple("no.es.un.jwt.de.verdad"),
  vacio: !!verificarJWTApple(""),
  prefijoBueno: primerTokenValidoApple("ruido " + bueno + " ruido") === bueno,
  prefiereBueno: primerTokenValidoApple(otroKid + " " + bueno) === bueno,
  candidatos: tokensJWTApple(otroKid + " " + bueno).length
};
process.stdout.write(JSON.stringify(salida));
`

// TestAppleMusicVerificaElTokenAntesDeAdoptarlo corre la verificación real contra
// tokens fabricados. Es la prueba de que el filtro distingue el token del web
// player de los otros JWT del bundle y de los vencidos.
func TestAppleMusicVerificaElTokenAntesDeAdoptarlo(t *testing.T) {
	salida := ejecutarLogicaExtension(t, "apple-music", guionAppleToken)

	var got struct {
		Bueno         bool `json:"bueno"`
		OtroKid       bool `json:"otroKid"`
		OtroAlg       bool `json:"otroAlg"`
		Vencido       bool `json:"vencido"`
		SinExp        bool `json:"sinExp"`
		Basura        bool `json:"basura"`
		Vacio         bool `json:"vacio"`
		PrefijoBueno  bool `json:"prefijoBueno"`
		PrefiereBueno bool `json:"prefiereBueno"`
		Candidatos    int  `json:"candidatos"`
	}
	if err := json.Unmarshal([]byte(salida), &got); err != nil {
		t.Fatalf("salida del arnés ilegible (%v): %s", err, salida)
	}

	if !got.Bueno {
		t.Error("un JWT ES256/WebPlayKid con exp futura fue rechazado: la verificación rechaza tokens válidos")
	}
	if got.OtroKid {
		t.Error("un JWT con kid ajeno pasó la verificación: se adoptaría el token equivocado")
	}
	if got.OtroAlg {
		t.Error("un JWT con alg HS256 pasó la verificación: no se exige ES256")
	}
	if got.Vencido {
		t.Error("un JWT ya vencido pasó la verificación: se cachearía un token muerto")
	}
	if got.SinExp {
		t.Error("un JWT sin exp pasó la verificación: no se puede saber cuándo renovarlo")
	}
	if got.Basura || got.Vacio {
		t.Error("un texto que no es un JWT de 3 partes pasó la verificación")
	}
	if !got.PrefijoBueno {
		t.Error("primerTokenValidoApple no encontró el token bueno embebido en texto")
	}
	if !got.PrefiereBueno {
		t.Error("primerTokenValidoApple no saltó el JWT de otro kid para quedarse con el del web player")
	}
	if got.Candidatos != 1 {
		t.Errorf("tokensJWTApple contó %d candidatos, se esperaba 1 (solo el del web player)", got.Candidatos)
	}
}
