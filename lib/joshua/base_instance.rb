class Joshua
  class Error < StandardError
  end

  ANNOTATIONS   ||= {}
  RESCUE_FROM   ||= {}
  OPTS          ||= { api: {} }
  PLUGINS       ||= {}
  MODELS        ||= {}
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
    :api_host,
    :request,
    :response,
    :uid

  attr_reader :api

  def initialize action, params: {}, opts: {}, development: false, id: nil, bearer: nil, api_host: nil, html_safe: true
    @api = INSTANCE.new

    if action.is_a?(Array)
      # unpack id and action is action is given in path form # [123, :show]
      @api.id, @api.action = action[1] ? action : [nil, action[0]]
    else
      @api.action = action
    end

    if html_safe
      params = Joshua.make_hash_html_safe params
    end

    @api.bearer        = bearer
    @api.id          ||= id
    @api.action        = @api.action.to_sym
    @api.request       = api_host ? api_host.request : nil
    @api.method_opts   = self.class.opts.dig(@api.id ? :member : :collection, @api.action) || {}
    @api.development   = !!development
    @api.params        = HashWia.new params
    @api.opts          = HashWia.new opts
    @api.api_host      = api_host
    @api.response      = ::Joshua::Response.new @api
  end

  def execute_call
    allow_type   = @api.method_opts[:allow] || 'POST'
    request_type = @api.request&.request_method || 'POST'
    is_allowed   = @api.development || ['POST', allow_type].include?(request_type)

    if is_allowed
      begin
        parse_api_params
        parse_annotations unless response.error?
        resolve_api_body  unless response.error?
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
    else
      response.error '%s request is not allowed' % request_type
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

  def parse_api_params
    params = @api.method_opts[:params]
    typero = @api.method_opts[:_typero]

    if params && typero
      # add validation errors
      typero.validate @api.params do |name, error|
        response.error_detail name, error
      end
    end
  end

  def resolve_api_body &block
    # if we have model defiend, we execute member otherwise collection
    type = @api.id ? :member : :collection
    api_method = '_api_%s_%s' % [type, @api.action]

    unless respond_to?(api_method)
      raise Joshua::Error, "Api method #{type}:#{@api.action} not found"
    end

    # execute before "in the wild"
    # model @api.pbject should be set here
    execute_callback :before_all

    instance_exec &block if block

    execute_callback 'before_%s' % type

    data = send api_method
    response.data data unless response.data?

    # after blocks
    execute_callback 'after_%s' % type
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
          instance_exec response.data, &before
        end
      end
    end
  end

  def response content_type=nil
    if block_given?
      @api.raw = yield

      api_host do
        response.header['Content-Type'] = content_type || (@api.raw[0] == '{' ? 'application/json' : 'text/plain')
      end
    elsif content_type
      response.data = content_type
    else
      @api.response
    end
  end

  def params
    @api.params
  end

  # inline error raise
  def error text, args={}
    if @api.development
      puts 'JOSHUA API Error: %s (%s)' % [text, caller[0]]
    end

    if err = RESCUE_FROM[text]
      if err.is_a?(Proc)
        err.call
        return
      else
        response.error err, args
      end
    else
      rr text if respond_to?(:rr)
      response.error text, args
    end

    raise Joshua::Error, text
  end

  def message data
    response.message data
  end

  def super! name=nil
    type   = @api.id ? :member : :collection
    name ||= caller[0].split("'").last.sub("'", '').split('#').last
    name   = "_api_#{type}_#{name}"
    self.class.superclass.instance_method(name).bind(self).call
  end

  # execute actions on api host
  def api_host &block
    if block_given? && @api.api_host
      @api.api_host.instance_exec self, &block
    end

    @api.api_host
  end

end
