package download

// finalResult construye el Result de fallo con la clasificación final del
// error (verificación requerida gana sobre errores genéricos).
func (st *fallbackState) finalResult(itemID string) *Result {
	if st.encryptedSeen {
		st.lastErr = "solo stream encriptado no reproducible en todos los providers"
	}
	errType := clasificarErrorVerificacion(st.lastErr)
	if errType == "" && esFalloEscrituraAlmacenamiento(st.lastErr) {
		errType = "storage_write_failure"
	}
	// Un proveedor tiene el canción pero necesita su signed sesión / cloudflare
	// challenge completed. That is strictly more actionable than "all providers
	// failed": completing the verification makes the song play. Surface it as
	// verification_required with the right service so the client opens the
	// verification modal for THAT provider.
	if st.verificationSeen && errType == "" {
		errType = "verification_required"
		st.lastErr = "verificacion requerida en " + st.verificationService
	}
	return &Result{
		ItemID:    itemID,
		Success:   false,
		Provider:  st.verificationService,
		Error:     st.lastErr,
		ErrorType: errType,
		Service:   st.verificationService,
	}
}
