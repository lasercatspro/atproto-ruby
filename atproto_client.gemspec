lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'atproto_client/version'

Gem::Specification.new do |spec|
  spec.name = 'atproto_client'
  spec.version = AtProto::VERSION
  spec.authors = ['frabr']
  spec.email = ['francois@lasercats.fr']
  spec.summary = 'AT Protocol client implementation for Ruby'
  spec.description = 'A Ruby client for the AT Protocol authenticated request'
  spec.homepage = 'https://github.com/lasercats/atproto_client'
  spec.license = 'MIT'

  spec.files = Dir['{lib}/**/*', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency 'jwt', '~> 2.7'
  spec.add_dependency 'openssl', '~> 3.0'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'vcr', '~> 6.1'
  spec.add_development_dependency 'webmock', '~> 3.18'
  spec.add_development_dependency 'yard', '~> 0.9'
end
