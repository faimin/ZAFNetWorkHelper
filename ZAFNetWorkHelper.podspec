Pod::Spec.new do |s|
  s.name         = "ZAFNetWorkHelper"
  s.version      = "0.0.1"
  s.summary      = "The package of requests including GET && POST with AFNetWorking"
  s.homepage     = "https://github.com/faimin/ZAFNetWorkHelper"
  s.license      = 'MIT'
  s.authors      = { 'Bourne' => 'fuxianchao@gmail.com'}
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/faimin/ZAFNetWorkHelper.git", :tag => s.version }
  s.source_files = 'ZAFNetWorkHelper', 'ZAFNetWorkHelper/*.{h,m}'
  s.requires_arc = true
  s.dependency 'AFNetworking', "~>2.0"
end