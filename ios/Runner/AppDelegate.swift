import Flutter
import UIKit

// El framework Go (gomobile bind -target=ios → Gobackend.xcframework) se
// embebe vía el pod local GoBackend (GoBackend.podspec). Si no está presente
// (clone del repo sin compilar el framework), la app compila igual y el
// canal responde con un error claro en vez de fallar el build.
#if canImport(GoBackend)
import GoBackend
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.bitly/backend"

  // Enlaces entrantes: el MISMO contrato que Android (MainActivity.kt).
  // Universal Link (https://<dominio>/open?s=...) y esquema propio
  // (bitly://open?s=...) llegan por acá y se reenvían a Dart, que muestra la
  // carta "te compartieron".
  private let DEEPLINK_CHANNEL = "com.bitly/deep_link"

  // Enlace que llegó antes de que Flutter estuviera listo (arranque en frío
  // con el link): Dart lo pide con getInitialDeepLink, igual que en Android.
  private var pendingDeepLink: String?

  // Las llamadas a Go corren en una cola propia: la init del runtime de Go
  // no es reentrante y una llamada lenta (JS de una extensión) no debe
  // bloquear el hilo principal de iOS. Cada respuesta vuelve a main.
  private let colaGo = DispatchQueue(label: "com.bitly.gobackend", qos: .userInitiated)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerBackendChannel()
    registerDeepLinkChannel()
    // Un enlace puede llegar un instante DESPUÉS de este método (cold start
    // con Universal Link): se reenvía cuando el motor ya está arriba.
    if pendingDeepLink != nil {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.reenviarEnlacePendiente()
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Canal de deep links: responde el enlace inicial (si lo había) y deja
  /// listo el reenvío al vuelo cuando la app ya está abierta.
  private func registerDeepLinkChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let canal = FlutterMethodChannel(name: DEEPLINK_CHANNEL, binaryMessenger: controller.binaryMessenger)
    canal.setMethodCallHandler { [weak self] llamada, resultado in
      switch llamada.method {
      case "getInitialDeepLink":
        let enlace = self?.pendingDeepLink ?? ""
        self?.pendingDeepLink = nil
        DispatchQueue.main.async { resultado(enlace) }
      default:
        resultado(FlutterMethodNotImplemented)
      }
    }
  }

  /// Universal Link (https://<dominio>/open?s=...).
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      manejarEnlace(url.absoluteString)
      return true
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  /// Esquema propio (bitly://open?s=...) y cualquier otro openURL.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if manejarEnlace(url.absoluteString) { return true }
    return super.application(app, open: url, options: options)
  }

  /// Reenvía el enlace a Dart si es un enlace de Bitly; si no, lo ignora para
  /// que otros plugins (OAuth, sesión firmada) lo reciban.
  @discardableResult
  private func manejarEnlace(_ enlace: String) -> Bool {
    let esBitly = enlace.lowercased().hasPrefix("bitly://")
      || enlace.lowercased().contains("://bitly.app/open")
    guard esBitly else { return false }
    pendingDeepLink = enlace
    reenviarEnlacePendiente()
    return true
  }

  /// Entrega el enlace pendiente por el canal (una sola vez).
  private func reenviarEnlacePendiente() {
    guard let enlace = pendingDeepLink else { return }
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    pendingDeepLink = nil
    let canal = FlutterMethodChannel(name: DEEPLINK_CHANNEL, binaryMessenger: controller.binaryMessenger)
    DispatchQueue.main.async {
      canal.invokeMethod("onDeepLink", arguments: enlace)
    }
  }

  private func registerBackendChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let canal = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    canal.setMethodCallHandler { [weak self] llamada, resultado in
      self?.colaGo.async { self?.despachar(llamada, resultado) }
    }
  }

  /// Rutea TODOS los métodos del canal por el dispatcher genérico InvokeRPC
  /// (bridge_rpc.go) — el mismo mapa de métodos que el servidor JSON-RPC de
  /// escritorio. Agregar un método nuevo en Go NO toca este archivo.
  private func despachar(_ llamada: FlutterMethodCall, _ resultado: @escaping FlutterResult) {
    switch llamada.method {
    case "getApplicationDocumentsDirectory":
      let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
      DispatchQueue.main.async { resultado(dir) }

    case "initGoBackend":
      // En iOS os.UserConfigDir()/Home no son utilizables dentro del sandbox:
      // Go apunta todos sus stores a Documents vía SetAppDataDir (el mismo
      // patrón que MainActivity.kt en Android). Luego initBackend +
      // initGlobalState por InvokeRPC (serializados en la cola Go).
      let args = llamada.arguments as? [String: Any]
      let dir = args?["app_data_dir"] as? String ?? ""
      #if canImport(GoBackend)
      if !dir.isEmpty { GoGobackend.setAppDataDir(dir) }
      let estado = rpcSeguro("initBackend", "{}") ?? "ok"
      let estadoGlobal = rpcSeguro("initGlobalState", "{}") ?? estado
      DispatchQueue.main.async { resultado(estadoGlobal) }
      #else
      DispatchQueue.main.async { resultado("stub_gobackend_not_embedded") }
      #endif

    default:
      #if canImport(GoBackend)
      let params = jsonParams(from: llamada.arguments)
      guard let respuesta = rpcSeguro(llamada.method, params) else {
        DispatchQueue.main.async {
          resultado(FlutterError(code: "BACKEND_ERROR", message: "Go devolvió nil", details: nil))
        }
        return
      }
      // InvokeRPC envuelve la respuesta en {"result": ...} / {"error": ...}.
      if let data = respuesta.data(using: .utf8),
         let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let err = obj["error"] as? String, !err.isEmpty {
          DispatchQueue.main.async {
            resultado(FlutterError(code: "BACKEND_ERROR", message: err, details: nil))
          }
        } else {
          let valor = obj["result"] ?? respuesta
          DispatchQueue.main.async { resultado(valor) }
        }
      } else {
        DispatchQueue.main.async { resultado(respuesta) }
      }
      #else
      DispatchQueue.main.async {
        resultado(FlutterError(
          code: "NO_GO",
          message: "Gobackend.xcframework no embebido — compila con el workflow de Apple",
          details: nil))
      }
      #endif
    }
  }

  #if canImport(GoBackend)
  /// Llamada al dispatcher genérico de Go (bridge_rpc.go). Nunca lanza:
  /// devuelve el JSON {"error": ...} como texto si Go falla por dentro.
  private func rpcSeguro(_ metodo: String, _ params: String) -> String? {
    GoGobackend.invokeRPC(metodo, params)
  }
  #endif

  private func jsonParams(from arguments: Any?) -> String {
    guard let args = arguments as? [String: Any], !args.isEmpty,
          let data = try? JSONSerialization.data(withJSONObject: args) else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }
}
