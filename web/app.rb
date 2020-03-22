set :haml, { escape_html: false }

API_CALL = proc do
  parts = request.path.split('/').drop(2)
  klass = parts.shift
  api   = ApplicationApi.call parts, class: klass, request: request, response: response, development: true
  api.to_json + "\n"
end

get '/' do
  redirect '/api'
end

get '/api' do
  CleanApi::Doc.render request: request
end

get '/api/*' do
  instance_exec &API_CALL
end

post '/api/*' do
  # data = JSON.load request.body.read

  instance_exec &API_CALL
end