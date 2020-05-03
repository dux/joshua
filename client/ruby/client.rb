# api = JoshuaRemote.new 'http://localhost:4567/api', debug: true
# api.company(1).index
# api.call 'company/1/index'
# api.call [:company, 1, :index]
# api.call :company, 1, :index

require 'http'

class JoshuaClient
  def initialize root
    @root = root
    reset!
  end

  def method_missing name, *args
    reset! if @done

    @path.push name

    if @path[1] && @path[@path.length-1].is_a?(Symbol)
      # api.users.index {params}
      # last step, execute
      @params = args.first || {}
      call
    else
      # api.users(1) - member id given if present
      @path.push args.first if args.first
      self
    end
  end

  def call
    @done = true
    path  = ([@root] + @path).join '/'
    
    JSON.parse HTTP.post(path, form: @params || {}).to_s
  end

  def reset!
    @done   = false
    @path   = []
    @params = nil
    @id     = nil
  end
end

