#
# Be sure to run `pod lib lint SJLogger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJLogger'
  s.version          = '0.1.0'
  s.summary          = 'A powerful iOS network logger framework for debugging, similar to CocoaDebug.'

  s.description      = <<-DESC
  SJLogger is a comprehensive iOS network logging framework that helps developers debug network requests.
  
  Features:
  - Automatic HTTP/HTTPS request interception
  - TCP network monitoring
  - Real-time log recording and display
  - Floating window for quick access
  - Log search and filtering
  - Copy and share logs
  - URL pattern configuration
  - Detailed request/response information
  - Performance statistics
  - Thread-safe implementation
                       DESC

  s.homepage         = 'https://github.com/1401788197/SJLogger'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'shengjie' => 'shengjie@hai.group' }
  s.source           = { :git => 'https://github.com/1401788197/SJLogger.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.source_files = 'SJLogger/Classes/**/*.swift'
  
  s.frameworks = 'UIKit', 'Foundation', 'Network'
  
  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }
end
