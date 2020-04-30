class CleanApi
  INSTANCE ||= Struct.new 'CleanApiOpts',
    :action,
    :bearer,
    :development,
    :id,
    :method_opts,
    :opts,
    :params,
    :raw,
    :rack_response,
    :request,
    :response,
    :uid

  attr_reader :api

  class << self
    # here we capture member & collection metods
    def method_added name
      return if name.to_s.start_with?('_api_')
      return unless @method_type

      set @method_type, name, PARAMS.fetch_and_clear_opts

      alias_method "_api_#{@method_type}_#{name}", name
      remove_method name
    end

    # perform auto_mount from a rake call
    def call env
      request = Rack::Request.new env

      if request.path == '/favicon.ico'
        [
          200,
          { 'Cache-Control'=>'public; max-age=1000000' },
          [Doc.misc_file('favicon.png')]
        ]
      else
        data = auto_mount request: request, mount_on: '/', development: ENV['RACK_ENV'] == 'development'

        if data[0] == '{'
          [
            200,
            { 'Content-Type' => 'application/json', 'Cache-Control'=>'private; max-age=0' },
            [data]
          ]
        else
          [
            200,
            { 'Content-Type' => 'text/html', 'Cache-Control'=>'public; max-age=3600' },
            [data]
          ]
        end
      end
    end

    # ApplicationApi.auto_mount request: request, response: response, mount_on: '/api', development: true
    # auto mount to a root
    # * display doc in a root
    # * call methods if possible /api/v1.comapny/1/show
    def auto_mount request:, response:, mount_on: nil, bearer: nil, development: false
      mount_on = [request.base_url, mount_on].join('') unless mount_on.to_s.include?('//')

      if request.url == mount_on && request.request_method == 'GET'
        response.header['Content-Type'] = 'text/html'

        Doc.render request: request, bearer: bearer
      else
        response.header['Content-Type'] = 'application/json'

        body     = request.body.read.to_s
        body     = body[0] == '{' ? JSON.parse(body) : nil

        # class: klass, params: params, bearer: bearer, request: request, response: response, development: development
        opts = {}
        opts[:request]     = request
        opts[:response]    = response
        opts[:development] = development
        opts[:bearer]      = bearer

        action =
        if body
          # {
          #   "id": 'foo',         # unique ID that will be returned, as required by JSON RPC spec
          #   "class": 'v1/users', # v1/users => V1::UsersApi
          #   "action": 'index',   # "index' or "6/info" or [6, "info"]
          #   "token": 'ab12ef',   # api_token (bearer)
          #   "params": {}         # methos params
          # }
          opts[:params] = body['params'] || {}
          opts[:bearer] = body['token'] if body['token']
          opts[:class]  = body['class']

          body['action']
        else
          opts[:params] = request.params || {}
          opts[:bearer] = opts[:params][:api_token] if opts[:params][:api_token]

          mount_on = mount_on+'/' unless mount_on.end_with?('/')
          path     = request.url.split(mount_on, 2).last.split('?').first.to_s
          parts    = path.split('/')

          opts[:class] = parts.shift
          parts
        end

        opts[:bearer] ||= request.env['HTTP_AUTHORIZATION'].to_s.split('Bearer ')[1]

        api_response = render action, **opts

        if api_response.is_a?(Hash)
          response.status = api_response[:status] if response
          api_response.to_h
        else
          api_response
        end
      end
    end

    def render action, opts={}
      return error 'Action not defined' unless action[0]

      api_class =
      if klass = opts.delete(:class)
        # /api/_/foo
        if klass == '_'
          if CleanApi::DocSpecial.respond_to?(action.first)
            return CleanApi::DocSpecial.send action.first.to_sym
          else
            return error 'Action %s not defined' % action.first
          end
        end

        klass = klass.split('/') if klass.is_a?(String)
        klass[klass.length-1] += '_api'

        begin
          klass.join('/').classify.constantize
        rescue NameError => e
          return error 'API class "%s" not found' % klass
        end
      else
        self
      end

      api = api_class.new action, **opts
      api.execute_call
    end

    private

    def only_in_api_methods!
      raise ArgumentError, "Available only inside collection or member block for API methods." unless @method_type
    end

    def set_callback name, block
      name = [name, @method_type || :all].join('_').to_sym
      set name, []
      OPTS[to_s][name].push block
    end
  end

  ###

  def initialize action, id: nil, bearer: nil, params: {}, opts: {}, request: nil, response: nil, development: false
    @api = INSTANCE.new

    if action.is_a?(Array)
      # unpack id and action is action is given in path form # [123, :show]
      @api.id, @api.action = action[1] ? action : [nil, action[0]]
    else
      @api.action = action
    end

    @api.bearer   = bearer
    @api.id          ||= id
    @api.action        = @api.action.to_sym
    @api.request       = request
    @api.method_opts   = self.class.opts.dig(@api.id ? :member : :collection, @api.action) || {}
    @api.development   = !!development
    @api.rack_response = response
    @api.params        = ::CleanHash::Indifferent.new params
    @api.opts          = ::CleanHash::Indifferent.new opts
    @api.response      = ::CleanApi::Response.new @api
  end

  def message data
    response.message data
  end

  def execute_call
    if !@api.development && @api.request && @api.request_method == 'GET' && !@api.method_opts[:gettable]
      response.error 'GET request is not allowed'
    else
      parse_api_params
      parse_annotations unless response.error?
      resolve_api_body unless response.error?
    end

    @api.raw || response.render
  end

  def resolve_api_body &block
    begin
      # execute before "in the wild"
      # model @api.pbject should be set here
      execute_callback :before_all

      instance_exec &block if block

      # if we have model defiend, we execute member otherwise collection
      type   = @api.id ? :member : :collection

      execute_callback 'before_%s' % type
      api_method = '_api_%s_%s' % [type, @api.action]
      raise CleanApi::Error, "Api method #{type}:#{@api.action} not found" unless respond_to?(api_method)
      data = send api_method
      response.data data unless response.data?

      # after blocks
      execute_callback 'after_%s' % type
    rescue CleanApi::Error => error
      # controlled error raised via error "message", ignore
      response.error error.message
    rescue => error
      CleanApi.error_print error

      block = RESCUE_FROM[error.class] || RESCUE_FROM[:all]

      if block
        instance_exec error, &block
      else
        # uncontrolled error, should be logged
        # search to response[:code] 500 in after block
        response.error error.message
        response.error :class, error.class.to_s
        response.error :code, 500
      end
    end

    # we execute generic after block in case of error or no
    execute_callback :after_all
  end

  def to_json
    execute_call.to_json
  end

  def to_h
    execute_call
  end

  private

  def parse_api_params
    return unless @api.method_opts[:params]

    parse = CleanApi::Params::Parse.new

    for name, opts in @api.method_opts[:params]
      # enforce required
      if opts[:required] && @api.params[name].to_s == ''
        response.error_detail name, 'Argument missing'
        next
      end

      begin
        # check and coerce value
        @api.params[name] = parse.check opts[:type], @api.params[name], opts
      rescue CleanApi::Error => error
        # add to details if error found
        response.error_detail name, error.message
      end
    end
  end

  def parse_annotations
    for key, opts in (@api.method_opts[:annotations] || {})
      instance_exec *opts, &ANNOTATIONS[key]
    end
  end

  def execute_callback name
    self.class.ancestors.reverse.map(&:to_s).each do |klass|
      if before_list = (OPTS.dig(klass, name.to_sym) || [])
        for before in before_list
          instance_exec &before
        end
      end
    end
  end

  def response content_type=nil
    if block_given?
      @api.raw = yield

      if @api.rack_response
        @api.rack_response.header['Content-Type'] = content_type || (@api.raw[0] == '{' ? 'application/json' : 'text/plain')
      end
    else
      @api.response
    end
  end

  def params
    @api.params
  end

end
