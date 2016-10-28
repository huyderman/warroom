lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'war_room/version'

Gem::Specification.new do |spec|
  spec.name          = 'war_room'
  spec.version       = WarRoom::VERSION
  spec.authors       = ['Jo-Herman Haugholt']
  spec.email         = ['johannes@huyderman.com']

  spec.summary       = %q{Toolsuite for RPGs}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'trollop', '~> 2.1'
  spec.add_runtime_dependency 'dry-types', '~> 0.9.0'
  spec.add_runtime_dependency 'dry-struct', '~> 0.1.0'
  spec.add_runtime_dependency 'dry-initializer', '~> 0.7.0'
  spec.add_runtime_dependency 'tty-table', '~> 0.6.0'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry', '~> 0.10.0'
  spec.add_development_dependency 'rubocop', '~> 0.34.0'
  spec.add_development_dependency 'reek', '~> 3.4'
end
