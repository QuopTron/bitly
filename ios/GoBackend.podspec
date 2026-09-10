# GoBackend.podspec — embebe el framework Go (gomobile) en la app iOS.
#
# El workflow de Apple compila el framework ANTES de flutter build ios:
#   gomobile bind -target=ios -o ios/Frameworks/Gobackend.xcframework .
# (desde go_backend/) y este podspec lo inyecta como vendored_framework.
# Si el .xcframework no está (build local sin compilar Go), el pod se
# declara vacío para que el build no muera — AppDelegate compila con el
# stub canImport(GoBackend) y el canal responde NO_GO.
#
# Se conecta con: ios/Podfile (pod 'GoBackend') + ios/Runner/AppDelegate.swift
# (import GoBackend) + go_backend/bridge_rpc.go (InvokeRPC).

Pod::Spec.new do |s|
  s.name             = 'GoBackend'
  s.version          = '0.9.10'
  s.summary          = 'Backend Go de Bitly embebido (gomobile).'
  s.description      = 'Framework Go compilado con gomobile bind; expone InvokeRPC y helpers de arranque al canal nativo de Flutter.'
  s.homepage         = 'https://github.com/zarz/bitly'
  s.license          = { :type => 'MIT' }
  s.authors          = { 'Bitly' => 'dev@bitly.local' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '14.0'
  if File.exist?('Frameworks/Gobackend.xcframework') || File.exist?('Frameworks/Gobackend.xcframework.zip')
    s.vendored_frameworks = 'Frameworks/Gobackend.xcframework'
  else
    # Sin framework: pod vacío. keeps pod install verde en builds locales.
    s.preserve_paths = ''
  end
end
