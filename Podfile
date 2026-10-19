# Uncomment this line to define a global platform for your project

platform :ios, '15.0'

target 'Overland' do
	pod 'FMDB', '2.7.12'
end

post_install do |installer|
	# Pods default to their own minimum deployment target, which current Xcode no longer supports.
	# Match the app's deployment target so the libraries run on every iOS version the app supports.
	installer.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
		end
	end

end

