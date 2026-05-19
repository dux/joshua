# Demo app for testing /api/sys/web in a real browser.
# Boot with: hammer test:web  (see Hammerfile at repo root)

ENV['RACK_ENV'] ||= 'development'

require 'sinatra/base'
require 'joshua'

Dir[File.expand_path('apis/*.rb', __dir__)].sort.each { |f| require f }

class HomeApp < Sinatra::Base
  get('/health') { 'ok' }
  get('/')       { redirect '/api/sys/web' }
end

# Joshua handles /api/* (uses mount_on internally to know its prefix).
# Sinatra handles everything else (/, /health).
api_handler = ->(env) {
  if env['PATH_INFO'].to_s.start_with?('/api')
    ApplicationApi.call(env)
  else
    HomeApp.call(env)
  end
}

run api_handler
