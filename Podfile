# Uncomment this line to define a global platform for your project

platform :ios, '15.0'

target 'Overland' do
	pod 'AFNetworking', '4.0.1'
	pod 'FMDB', '2.7.5'
end

post_install do |installer|
	# Pods default to their own minimum deployment target, which current Xcode no longer supports.
	# Match the app's deployment target so the libraries run on every iOS version the app supports.
	installer.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
		end
	end

	# AFNetworking 4.0.1 imports netinet6/in6.h, which newer SDKs treat as a private header.
	# netinet/in.h is already imported and provides the same definitions.
	Dir.glob(File.join(installer.sandbox.root, 'AFNetworking', '**', '*.m')).each do |path|
		contents = File.read(path)
		patched = contents.gsub("#import <netinet6/in6.h>\n", '')
		next if patched == contents
		File.chmod(0644, path)
		File.write(path, patched)
	end
end

