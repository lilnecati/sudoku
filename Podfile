platform :ios, '16.0'  # iOS hedef versiyonunuz

target 'Sudoku' do
  # Sandbox sorunları için dinamik framework kullan
  use_frameworks! :linkage => :dynamic
  
  # Basitleştirilmiş Firebase pod'ları - sadece Auth
  pod 'Firebase/Auth'
  pod 'Firebase/Storage'
  # Analytics'i kaldırdık: pod 'Firebase/Analytics'
  
  # iOS deployment target uyarılarını düzelt
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # iOS deployment target'i güncelle
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        
        # Script ve resource copy hatalarını önlemek için
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
        
        # Sandbox hatalarını önlemek için
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end
  end
end