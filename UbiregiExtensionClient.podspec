Pod::Spec.new do |spec|
  spec.name         = 'UbiregiExtensionClient'
  spec.version      = '0.1.0'
  spec.license      = { :type => 'MIT' }
  spec.homepage     = 'https://github.com/ubiregiinc/UbiregiExtensionClient'
  spec.authors      = { 'Soutaro Matsumoto' => 'soutaro@ubiregi.com' }
  spec.summary      = 'UbiregiExtension Client Class for iOS.'
  spec.source       = { :git => 'https://github.com/ubiregiinc/UbiregiExtensionClient.git', :tag => spec.version.to_s }
  spec.source_files = 'Pod/Classes/*'
  spec.platform     = :ios, "8.0"
  spec.requires_arc = true

  spec.dependency 'SMHTTPClient'
end
