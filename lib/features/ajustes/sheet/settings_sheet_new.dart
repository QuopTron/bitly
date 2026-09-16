// ─────────────────────────────────────────────────────────────
// settings_sheet_new.dart — Hoja de Ajustes principal: punto de entrada (showSettingsSheet),
// el widget SettingsSheet y la lista de pestañas burbuja. Reúne los
// parts que construyen las 4 pestañas y el perfil/estadísticas.
// Se conecta con: todos los settings_sheet_*.dart (parts) + cubits + caches.
// Parte del flujo: Ajustes (hoja modal).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/utilidades/plataforma/insets_sistema.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../core/modelos/ajustes_descarga.dart';
import '../../../core/modelos/usuario/estado_premium.dart';
import '../../../core/cache/reproduccion/reproduccion_cache.dart';
import '../../../core/cache/reproduccion/reproduccion_stats.dart';
import '../../../core/cache/estado/estado_cola.dart';
import '../../../core/cache/almacenes/cache_premium.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../estado/like/cubit_like.dart';
import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../core/servicios/playlist/importacion_biblioteca.dart';
import '../../../estado/reproductor/cubit_reproductor.dart';
import '../../../estado/cola/cubit_cola.dart';
import '../../../core/servicios/oauth/servicio_oauth_youtube.dart';
import '../../../core/servicios/compartir/compartido_recibido.dart';
import '../../../core/servicios/compartir/servicio_compartir.dart';
import '../../../core/servicios/compartir/servicio_historial_compartidos.dart';
import '../../../core/servicios/proveedores/servicio_soulseek.dart';
import '../../../config/secretos.dart';
import '../../../app/inyeccion.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';

import '../secciones/settings_sections_reset.dart';
import '../secciones/settings_cache_section.dart';
import '../secciones/settings_performance_section.dart';
import '../secciones/settings_storage_section.dart';
import '../update/update_modal.dart';
import '../../../shared/utilidades/portada/paleta_portada.dart';
import '../../../shared/utilidades/formato/estilo_helper.dart';
import '../../tutorial_interactivo/motor/tutorial_controller.dart';
import '../../tutorial_interactivo/motor/tutorial_pasos.dart';
import '../../../shared/widgets/tarjetas/portada/imagen_portada.dart' show imagenDesdeUrl;
import '../../../core/modelos/usuario/estilo_visual.dart';
import '../../../core/modelos/usuario/preferencias_estilo.dart';
import '../../../core/modelos/usuario/perfil_rendimiento.dart';
import '../../../shared/widgets/vidrio/desenfoque_adaptativo.dart';
part 'settings_sheet_entry.dart';

part 'settings_sheet_background.dart';
part 'settings_sheet_profile_header.dart';
part 'settings_sheet_appearance.dart';
part 'settings_sheet_appearance_theme.dart';
part 'settings_sheet_appearance_style.dart';
part 'settings_sheet_appearance_granular.dart';
part 'settings_sheet_appearance_toggle.dart';
part 'settings_sheet_appearance_tile.dart';
part 'settings_sheet_downloads_tab.dart';
part 'settings_sheet_performance.dart';
part 'settings_sheet_release_info.dart';
part 'settings_sheet_bubble_tab.dart';
part 'settings_sheet_stats.dart';
part 'settings_sheet_stats_sections.dart';
part 'settings_sheet_stats_top_section.dart';
part 'settings_sheet_stats_widgets.dart';
part 'settings_sheet_trial_chip.dart';
part 'settings_sheet_download_quality.dart';
part 'settings_sheet_download_rows.dart';
part 'settings_sheet_download_picker.dart';
part 'settings_sheet_download_labels.dart';
part 'settings_sheet_download_quality_helpers.dart';
part 'settings_sheet_more_tab.dart';
part 'settings_sheet_google_tile.dart';
part 'settings_sheet_google_content.dart';
part 'settings_sheet_google_connect.dart';
part 'settings_sheet_more_premium.dart';
part 'settings_sheet_premium_activation_card.dart';
part 'settings_sheet_premium_sheet.dart';
part 'settings_sheet_premium_widgets.dart';
part 'settings_sheet_premium_form.dart';
part 'settings_sheet_more_report.dart';
part 'settings_sheet_report_dialog.dart';
part 'settings_sheet_report_title.dart';
part 'settings_sheet_report_submit.dart';
part 'settings_sheet_report_chip.dart';
part 'settings_sheet_report_type_toggle.dart';
part 'settings_sheet_more_cards.dart';
part 'settings_sheet_soulseek_card.dart';
part 'settings_sheet_soulseek_tile.dart';
part 'settings_sheet_soulseek_tile_visual.dart';
part 'settings_sheet_soulseek_sheet.dart';
part 'settings_sheet_soulseek_sheet_visual.dart';
part 'settings_sheet_soulseek_form.dart';
part 'settings_sheet_soulseek_password.dart';
part 'settings_sheet_soulseek_header.dart';
part 'settings_sheet_cache_card.dart';
part 'settings_sheet_biblioteca_local.dart';
part 'settings_sheet_version_sheet.dart';
part 'settings_sheet_version_releases.dart';
part 'settings_sheet_sheet_state.dart';
part 'settings_sheet_version_tile.dart';
part 'settings_sheet_version_download_button.dart';
part 'settings_sheet_version_status.dart';
part 'settings_sheet_version_download.dart';
part 'settings_sheet_version_load.dart';
part 'settings_sheet_stats_top_tile.dart';
part 'settings_sheet_stats_helpers.dart';
part 'settings_sheet_sheet_build.dart';
part 'settings_sheet_sheet_widgets.dart';
part 'settings_compartidos_tab.dart';
part 'settings_compartidos_fila.dart';
part 'settings_sheet_body_state.dart';
part 'settings_sheet_report_dialog_contenido.dart';
part 'settings_sheet_soulseek_form_build.dart';
part 'settings_sheet_biblioteca_local_build.dart';
