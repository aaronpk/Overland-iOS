# Uncomment this line to define a global platform for your project

platform :ios, '15.0'

target 'Overland' do
	pod 'AFNetworking', '4.0.1'
	pod 'FMDB', '2.7.5'
end

post_install do |installer|
  # Raise every pod's deployment target to 15.0
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end

  # Remove the private netinet6 import from AFNetworking
  Dir.glob('Pods/AFNetworking/**/*.m').each do |f|
    text = File.read(f)
    patched = text.gsub(/^#import <netinet6\/in6\.h>\n/, '')
    if patched != text
      File.chmod(0644, f)
      File.write(f, patched)
    end
  end
end
