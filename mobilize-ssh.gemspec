# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mobilize-ssh/version'

Gem::Specification.new do |gem|
  gem.name          = "mobilize-ssh"
  gem.version       = Mobilize::Ssh::VERSION
  gem.authors       = ["Cassio Paes-Leme", "Ryosuke IWANAGA"]
  gem.email         = ["cpaesleme@dena.com", "riywo.jp@gmail.com"]
  gem.license       = "Apache License, Version 2.0"
  gem.homepage      = "http://github.com/DeNA/mobilize-ssh"
  gem.description   = %q{mobilize-ssh allows you to automate ssh commands and files across hosts}
  gem.summary       = %q{extend mobilize-base with the ability to run files across hosts}

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_runtime_dependency "mobilize-base","1.383"
  gem.add_runtime_dependency "net-ssh"
  gem.add_runtime_dependency "net-scp"
  gem.add_runtime_dependency "net-ssh-gateway"

end
