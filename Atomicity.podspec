

Pod::Spec.new do |s|
  s.name             = 'Atomicity'
  s.version          = '1.0.0'
  s.summary          = 'Atomicity lock'

  s.homepage         = 'https://github.com/GodL/Atomic'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '547188371@qq.com' => '547188371@qq.com' }
  s.source           = { :git => 'https://github.com/GodL/Atomic.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.source_files = 'Atomic/Atomic/**.{swift,h}'
  
  s.swift_version = '5'
end
