Pod::Spec.new do |s|
  s.name         = "SocialAuth"
  s.version      = "1.0.1"
  s.summary      = "Painless Facebook & Twitter auth on iOS 6+."
  s.homepage     = "http://github.com/evadne/SocialAuth"
  s.author       = { "Evadne Wu" => "ev@radi.ws" }
  s.source       = { :git => "git://github.com/evadne/SocialAuth.git", :tag => "1.0.1" }
  s.platform     = :ios, '6.0'
  s.source_files = 'SocialAuth', 'SocialAuth/**/*.{h,m}'
  s.exclude_files = 'SocialAuth/Exclude'
  s.frameworks = 'Accounts', 'Social', 'QuartzCore'
  s.requires_arc = true
end
