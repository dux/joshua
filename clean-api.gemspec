gem_files = [:lib]
  .inject([]) { |t, el| t + `find ./#{el}`.split($/) }
  .push './.version'

Gem::Specification.new 'clean-api' do |gem|
  gem.version     = File.read('.version')
  gem.summary     = 'Clean API'
  gem.description = 'Ruby language based, framework agnostic API request/response lib'
  gem.homepage    = 'http://github.com/dux/clean-api'
  gem.license     = 'MIT'
  gem.author      = 'Dino Reic'
  gem.email       = 'rejotl@gmail.com'
  gem.files       = gem_files

  gem.executables = []

  gem.add_runtime_dependency 'dry-inflector'
  gem.add_runtime_dependency 'json'
end