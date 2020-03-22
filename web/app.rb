set :haml, { escape_html: false }

API_CALL = proc do
  ApplicationApi.auto_mount request: request,
    response: response,
    mount_on: '/api',
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