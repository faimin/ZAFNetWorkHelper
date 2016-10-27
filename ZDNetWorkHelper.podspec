source 'https://github.com/CocoaPods/Specs.git'

Pod::Spec.new do |s|
  s.name         = 'ZDNetWorkHelper'
  s.version      = '0.3.1'
  s.summary      = "Package AFNetWorking's(~>3.0) GET && POST && UPDATE && DOWNLOAD request "
  s.homepage     = 'https://github.com/faimin/ZDNetWorkHelper'
  s.license      = 'MIT'
  s.authors      = {'Zero.D.Saber' => 'fuxianchao@gmail.com'}
  s.platform     = :ios, "7.0"
  s.source       = { 
    :git => "https://github.com/faimin/ZDNetWorkHelper.git", 
    :tag => s.version }
  s.source_files = 'ZDNetWorkHelper/*.{h,m}'
  s.requires_arc = true
  s.dependency 'AFNetworking', "~>3.0.4"
end