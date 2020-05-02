gem_files = [:lib]
  .inject([]) { |t, el| t + `find ./#{el}`.split($/) }
  .push './.version'

Gem::Specification.new 'joshua' do |gem|
  gem.version     = File.read('.version')
  gem.summary     = 'Joshua'
  gem.description = 'Ruby language based, framework agnostic API request/response lib'
  gem.homepage    = 'http://github.com/dux/joshua'
  gem.license     = 'MIT'
  gem.author      = 'Dino Reic'
  gem.email       = 'rejotl@gmail.com'
  gem.files       = gem_files

  gem.executables = []

  gem.add_runtime_dependency 'dry-inflector'
  gem.add_runtime_dependency 'json'
  gem.add_runtime_dependency 'html-tag'
  gem.add_runtime_dependency 'clean-hash'
  gem.add_runtime_dependency 'rack'
  gem.add_runtime_dependency 'http'
end