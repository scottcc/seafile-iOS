use_frameworks!
inhibit_all_warnings!

def shared
  platform :ios, '8.0'
  pod 'Seafile', :path => "./"
  pod 'AFNetworking', '~> 2.6.1'
  pod 'OpenSSL-Universal', '~> 1.0.1.p'
end

target :"seafile-appstore" do
  pod 'SVPullToRefresh', '~> 0.4.1'
  pod 'SVProgressHUD', '~> 1.1.3'
  pod 'SWTableViewCell', :git => 'https://github.com/haiwen/SWTableViewCell.git', :branch => 'master'
  pod 'MWPhotoBrowserPlus', '2.1.6'
  pod 'QBImagePickerControllerPlus', :git => 'https://github.com/scottcc/QBImagePickerControllerPlus.git', :commit => 'f0220b04c689bd998e3fbdce82c19d788300437f'
  shared
end

target :"SeafProvider" do
  shared
end

target :"SeafProviderFileProvider" do
  shared
end

target :"SeafAction" do
  pod 'SVPullToRefresh', '~> 0.4.1'
  shared
end

pre_install do |installer|
    # workaround for https://github.com/CocoaPods/CocoaPods/issues/3289
    def installer.verify_no_static_framework_transitive_dependencies; end
end

post_install do |installer|
   installer.pods_project.targets.each do |target|
       target.build_configurations.each do |config|
           config.build_settings['SWIFT_VERSION'] = '3.0.2'
           if target.name == "Seafile"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
           end
           if target.name == "SeafProvider"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
           end
           if target.name == "SeafProviderFileProvider"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
           end
           if target.name == "SeafAction"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
           end
           if target.name == "SVProgressHUD"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
           end
           if target.name == "MWPhotoBrowserPlus"
               config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
           end
       end
   end
end

