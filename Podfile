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
  pod 'MWPhotoBrowser', :git => 'https://github.com/haiwen/MWPhotoBrowser.git', :branch => 'master'
  pod 'QBImagePickerController', :git => 'https://github.com/haiwen/QBImagePickerController.git', :branch => 'master'
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
