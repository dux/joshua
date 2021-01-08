require 'rubygems'
require 'bundler'

Bundler.require :default, :web

require './spec/base'

###

set :haml, { escape_html: false }

API_CALL = proc do
  data = ApplicationApi.auto_mount api_host: self, mount_on: '/api', development: true

  data.is_a?(Hash) ? data.to_json : data
end

get '/' do
  redirect '/api'
end

get '/api*' do
  instance_exec &API_CALL
end

post '/api*' do
  instance_exec &API_CALL
end