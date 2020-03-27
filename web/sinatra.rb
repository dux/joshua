require 'rubygems'
require 'bundler'

Bundler.require :default, :web

require './spec/base'

###

set :haml, { escape_html: false }

API_CALL = proc do
  ApplicationApi.auto_mount mount_on: '/api',
    request: request,
    response: response,
    development: true
end

get '/' do
  redirect '/api'
end

get '/api*' do
  instance_exec &API_CALL
end

post '/api/*' do
  instance_exec &API_CALL
end