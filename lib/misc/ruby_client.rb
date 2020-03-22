require 'http'

# api = CleanApiRemote.new 'http://localhost:4567/api', debug: true
# api.company(1).index
# api.call 'company/1/index'
# api.call [:company, 1, :index]
# api.call :company, 1, :index
# api.success?
# api.response
class CleanApiRemote
  attr_reader :response

  def initialize root, debug: false
    @debug = debug
    @root  = root
    @path  = []
  end

  def method_missing name, *args
    @path.push name
    return call if @path[1]
    @path.push args.first if args.first
    self
  end

  def call *args
    path =
    if args.first
      args = args.flatten
      args[1] ? args.join('/') : args.first
    else
      '/' + @path.join('/')
    end

    path = [@root, path].join('/')
    puts 'CleanApi: %s' % path if @debug

    @path     = []
    @response = JSON.parse HTTP.get(path).to_s
  end

  def success?
    @response['success'] == true
  end

  def error?
    !success?
  end
end

require 'awesome_print'

# api = CleanApiRemote.new 'http://localhost:4567/api', debug: true
# ap api.company(1).ivor
# ap api.call 'company/1/index'
# ap api.call [:company, 1, :index]
# ap api.call :company, 1, :index
# ap api.success?
# ap api.response


