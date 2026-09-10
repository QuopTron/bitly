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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
