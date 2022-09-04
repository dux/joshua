require 'rubygems'
require 'bundler'

Bundler.require :dev, :web

require './spec/base'
require_relative '../spec/lib/blank'

###

set :haml, { escape_html: false }

API_CALL = proc do
  data = ApplicationApi.auto_mount api_host: self, mount_on: '/api', development: true

  data.is_a?(Hash) ? data.to_json : data
end

get '/' do
  redirect '/api'
end

%i(get post put patch delete).each do |m|
  send(m, '/api*') do
    instance_exec &API_CALL
  end
end
