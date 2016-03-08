Pod::Spec.new do |s|
  s.name         = "ZDAFNetWorkHelper"
  s.version      = "0.3.0"
  s.summary      = "Package AFNetWorking's(~>3.0) GET && POST request "
  s.homepage     = "https://github.com/faimin/ZDAFNetWorkHelper"
  s.license      = 'MIT'
  s.authors      = { 'Zero.D.Saber' => 'fuxianchao@gmail.com'}
  s.platform     = :ios, "7.0"
  s.source       = { 
    :git => "https://github.com/faimin/ZDAFNetWorkHelper.git", 
    :tag => s.version }
  s.source_files = 'ZDAFNetWorkHelper', 'ZDAFNetWorkHelper/*.{h,m}'
  s.requires_arc = true
  s.dependency 'AFNetworking', "~>3.0.1"
end