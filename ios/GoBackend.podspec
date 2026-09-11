# GoBackend.podspec — embebe el framework Go (gomobile) en la app iOS.
#
# El workflow de Apple compila el framework ANTES de flutter build ios:
#   gomobile bind -target=ios -o ios/Frameworks/Gobackend.xcframework .
# (desde go_backend/) y este podspec lo inyecta como vendored_framework.
#
# Cuando el .xcframework no existe (build local), el pod queda vacío y
# AppDelegate compila con #if canImport(GoBackend) → stub funcional.
#
# Se conecta con: ios/Podfile (pod 'GoBackend', :path => '.') + ios/Runner/AppDelegate.swift

Pod::Spec.new do |s|
  s.name             = 'GoBackend'
  s.version          = '0.9.10'
  s.summary          = 'Backend Go de Bitly embebido (gomobile).'
  s.description      = 'Framework Go compilado con gomobile bind; expone InvokeRPC y helpers de arranque al canal nativo de Flutter.'
  s.homepage         = 'https://github.com/zarz/bitly'
  s.license          = { :type => 'MIT' }
  s.authors          = { 'Bitly' => 'dev@bitly.local' }
  s.source           = { :git => 'https://github.com/zarz/bitly.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'

  # Si el xcframework existe (generado por el workflow CI), lo embebe.
  # Si no (build local sin compilar Go), el pod queda vacío — no rompe
  # el build; AppDelegate compila con canImport(GoBackend) → stub.
  fw = 'Frameworks/Gobackend.xcframework'
  if File.exist?(fw) || File.exist?("#{fw}.zip")
    s.vendored_frameworks = fw
  else
    s.source_files = 'Classes/**/*'
  end
end
