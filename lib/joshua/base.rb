class Joshua
  class Error < StandardError
  end

  ANNOTATIONS   ||= {}
  RESCUE_FROM   ||= {}
  OPTS          ||= {}
  PLUGINS       ||= {}
  DOCUMENTED    ||= []
  INSTANCE      ||= Struct.new 'JoshuaOpts',
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
    @api.response      = ::Joshua::Response.new @api
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

  def to_json
    execute_call.to_json
  end

  def to_h
    execute_call
  end

  private

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
      raise Joshua::Error, "Api method #{type}:#{@api.action} not found" unless respond_to?(api_method)
      data = send api_method
      response.data data unless response.data?

      # after blocks
      execute_callback 'after_%s' % type
    rescue Joshua::Error => error
      # controlled error raised via error "message", ignore
      response.error error.message
    rescue => error
      # uncontrolled error, should be logged
      Joshua.error_print error if @api.development

      block = RESCUE_FROM[error.class] || RESCUE_FROM[:all]

      if block
        instance_exec error, &block
      else
        response.error error.message, status: 500
      end
    end

    # we execute generic after block in case of error or no
    execute_callback :after_all
  end

  def parse_api_params
    return unless @api.method_opts[:params]

    parse = Joshua::Params::Parse.new

    for name, opts in @api.method_opts[:params]
      # enforce required
      if opts[:required] && @api.params[name].to_s == ''
        response.error_detail name, 'Argument missing'
        next
      end

      begin
        # check and coerce value
        @api.params[name] = parse.check opts[:type], @api.params[name], opts
      rescue Joshua::Error => error
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

  # inline error raise
  def error text, args={}
    if err = RESCUE_FROM[text]
      if err.is_a?(Proc)
        err.call
        return
      else
        response.error err, args
      end
    else
      response.error text, args
    end

    raise Joshua::Error, text
  end

  def message data
    response.message data
  end
end
