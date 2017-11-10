Pod::Spec.new do |s|
  s.name             = "Seafile"
  s.version          = "2.6.10"
  s.summary          = "iOS client for seafile."
  s.homepage         = "https://github.com/haiwen/seafile-iOS"
  s.license          = 'MIT'
  s.author           = { "wei.wang" => "poetwang@gmail.com" }
  s.source           = { :git => "https://github.com/scottcc/seafile-iOS.git", 
                         :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Seafile'
  s.source_files     = 'Pod/Classes/**/*.{h,m}'
  s.resource_bundles = { 'Seafile' => 'Pod/Resources/**/*' }
  s.platform         = :ios, '8.0'
  s.requires_arc     = true
  s.frameworks       = 'AssetsLibrary'
  s.dependency 'AFNetworking', '~> 2.6.1'
  s.dependency 'OpenSSL-Universal', '~> 1.0.1.p'
  s.dependency 'SVPullToRefreshPlus', '~> 0.4.4.1'
  s.dependency 'SVProgressHUD', '~> 1.1.3'
  s.dependency 'NotDeadSWTableViewCell', '~> 0.3.9'
  s.dependency 'MWPhotoBrowserPlus', '~> 2.1.8'  
  s.dependency 'QBImagePickerControllerPlus', '2.2.2.4'  
  s.pod_target_xcconfig = {
    'LIBRARY_SEARCH_PATHS' => '$(inherited) $(PODS_ROOT)/OpenSSL-Universal/lib-ios/',
    'OTHER_LDFLAGS' => '$(inherited) -lssl -lcrypto'
  }
end
