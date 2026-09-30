// canales_diagnostico_test.go — Pruebas del informe de canales y del
// apagado explícito de espejos (mirrors=off).
//
// Por qué importan: son la única forma de sacar del rescate a un canal muerto
// sin abrir Ajustes a ciegas, y de saber si queda algo sano antes de esperar una
// reproducción entera. Los tests son offline por contrato (ver testmain_test.go).
//
// Se conecta con: canales_diagnostico.go y client.go.
// Parte del flujo: Ajustes → Credenciales → Rescate de audio.
package flacrescue

import "testing"

// TestApagarEspejosConOff fija el apagado explícito: sin esto no había forma de
// sacar del rescate al espejo de fábrica (con sus ARLs de Deezer muertos), porque
// el vacío significa "sin tocar".
func TestApagarEspejosConOff(t *testing.T) {
	c := NewClient()
	if len(c.Mirrors()) == 0 {
		t.Fatal("de fábrica tiene que haber al menos un espejo")
	}

	for _, apagado := range []string{"off", "0", "no", "false", "apagado"} {
		c.SetSettings(map[string]string{"mirrors": apagado})
		if n := len(c.Mirrors()); n != 0 {
			t.Fatalf("mirrors=%q debía apagar los espejos, quedan %d", apagado, n)
		}
	}

	// Y un valor válido los vuelve a encender.
	c.SetSettings(map[string]string{"mirrors": "https://vivo.example"})
	if n := len(c.Mirrors()); n != 1 {
		t.Fatalf("una URL válida debía reactivar los espejos, hay %d", n)
	}

	// El vacío sigue significando "sin tocar": no borra lo que ya había.
	c.SetSettings(map[string]string{"mirrors": ""})
	if n := len(c.Mirrors()); n != 1 {
		t.Errorf("mirrors vacío no debe tocar la lista, quedan %d", n)
	}

	// Y vacío sobre una lista VACÍA restauran los de fábrica: es lo que permite
	// volver a encender el switch después de apagarlos.
	c.SetSettings(map[string]string{"mirrors": "off"})
	if n := len(c.Mirrors()); n != 0 {
		t.Fatalf("mirrors=off debía dejarlos vacíos, hay %d", n)
	}
	c.SetSettings(map[string]string{"mirrors": ""})
	if n := len(c.Mirrors()); n != len(defaultMirrors) {
		t.Errorf("mirrors vacío debía restaurar los de fábrica (%d), hay %d", len(defaultMirrors), n)
	}
}

// TestDiagnosticoCanalesSinRed fija los estados que los canales ya publican.
func TestDiagnosticoCanalesSinRed(t *testing.T) {
	c := NewClient()

	porNombre := func() map[string]EstadoDeCanal {
		t.Helper()
		diag := c.DiagnosticoCanales()
		if len(diag.Canales) != 5 {
			t.Fatalf("esperaba 5 canales, obtuve %d: %+v", len(diag.Canales), diag.Canales)
		}
		m := map[string]EstadoDeCanal{}
		for _, ca := range diag.Canales {
			m[ca.Nombre] = ca
		}
		return m
	}

	// En tests, arcod y el relay vienen apagados y no hay claves de fábrica.
	m := porNombre()
	if m[nombreStashRelay].Estado != EstadoCanalApagado {
		t.Errorf("stash-relay: %q (detalle %q)", m[nombreStashRelay].Estado, m[nombreStashRelay].Detalle)
	}
	if m[nombreArcod].Estado != EstadoCanalApagado {
		t.Errorf("arcod: %q", m[nombreArcod].Estado)
	}
	if m[nombreQobuzFirmado].Estado != EstadoCanalApagado {
		t.Errorf("qobuz-firmado: %q", m[nombreQobuzFirmado].Estado)
	}
	if m[nombreEspejos].Estado != EstadoCanalOk {
		t.Errorf("espejos: %q (debía haber uno de fábrica sin marca)", m[nombreEspejos].Estado)
	}
	if m["sitios"].Estado != EstadoCanalOk {
		t.Errorf("sitios: %q", m["sitios"].Estado)
	}

	// Con los espejos apagados, el canal pasa a "sin_configurar" en vez de
	// mentir con un ok.
	c.SetSettings(map[string]string{"mirrors": "off"})
	if got := porNombre()[nombreEspejos].Estado; got != EstadoCanalSinConfigurar {
		t.Errorf("espejos apagados: %q, esperaba %q", got, EstadoCanalSinConfigurar)
	}
}
