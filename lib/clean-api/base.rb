class CleanApi
  INSTANCE ||= Struct.new 'CleanApiOpts', :action, :api, :request, :response, :params, :id, :opts, :klass_opts, :development, :bearer

  class << self
    # here we capture member & collection metods
    def method_added name
      return if name.to_s.start_with?('_api_')
      return unless @method_type

      set @method_type, name, PARAMS.fetch_and_clear_opts

      alias_method "_api_#{@method_type}_#{name}", name
      remove_method name
    end

    # ApplicationApi.auto_mount request: request, response: response, mount_on: '/api', development: true
    # auto mount to a root
    # * display doc in a root
    # * call methods if possible /api/v1.comapny/1/show
    def auto_mount request:, response:, mount_on:, development: false
      mount_on = [request.base_url, mount_on].join('') unless mount_on.include?('//')

      if request.url == mount_on
        Doc.render request: request
      else
        path  = request.url.split(mount_on+'/', 2).last.split('?').first
        parts = path.split('/')
        klass = parts.shift
        api = call parts, class: klass, request: request, response: response, development: development
        api.to_json + "\n"
      end
    end

    def call action, opts={}
      api_class =
      if klass = opts.delete(:class)
        klass = klass.split('/') if klass.is_a?(String)
        klass[klass.length-1] += '_api'

        begin
          klass.join('/').classify.constantize
        rescue NameError => e
          if opts[:development]
            error_print e
            return error '%s (%s)' % [e.message, self]
          else
            return error 'API class not found'
          end
        end
      else
        self
      end

      api = api_class.new action, **opts
      api.execute_call
    end

    def activated
      CleanApi::ACTIVATED.map(&:to_s).sort.map(&:constantize)
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

  def initialize action, id: nil, params: nil, opts: nil, request: nil, response: nil, bearer: nil, development: false
    @api = INSTANCE.new

    if action.is_a?(Array)
      # unpack id and action is action is given in path form # [123, :show]
      @api.id, @api.action = action[1] ? action : [nil, action[0]]
    else
      @api.action = action
    end

    @api.id ||= id

    # set response header if response given
    response.header['Content-Type'] = 'application/json' if response

    request_body = request.body.read.to_s

    # calculate the params hash
    @api.params ||=
    if params
      params
    elsif request && request_body[0] == '{'
      JSON.parse request_body
    elsif request
      request.params
    else
      {}
    end

    bearer ||=
    @api.bearer      = bearer

    # other options
    @api.opts        = CleanHash::Indifferent.new(opts|| {})
    @api.response    = CleanApi::Response.new
    @api.request     = request
    @api.klass_opts  = self.class.opts.dig(@api.id ? :member : :collection, @api.action) || {}
    @api.development = !!development
  end

  def message data
    response.message data
  end

  def execute_call
    if !@api.development && @api.request && @api.request_method == 'GET'
      response.error 'GET HTTP requests are not allowed in production'
    else
      parse_api_params
      parse_annotations
      resolve_api_body
    end

    response.render
  end

  def resolve_api_body &block
    begin
      # execute before "in the wild"
      # model @api.pbject should be set here
      execute_callback :before_all

      instance_exec &block if block

      return if response.error?

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
    @api.klass_opts[:params] ||= {}

    if @api.klass_opts[:params].keys.length > 0
      parse = CleanApi::Params::Parse.new

      for name, opts in @api.klass_opts[:params]
        # enforce required
        if opts[:required] && @api.params[name].to_s == ''
          response.error_detail name, 'Paramter is required'
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

    @api.params = CleanHash::Indifferent.new @api.params
  end

  def parse_annotations
    for key, opts in (@api.klass_opts[:annotations] || {})
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

  def response
    @api.response
  end

  def params
    @api.params
  end

end
