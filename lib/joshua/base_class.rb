class Joshua
  @@after_auto_mount = nil
  @@opts   = {}

  class << self
    # perform auto_mount from a rake call
    def call env = nil
      return render unless env

      request = Rack::Request.new env

      if request.path == '/favicon.ico'
        [
          200,
          { 'Cache-Control'=>'public; max-age=1000000' },
          [Doc.misc_file('favicon.png')]
        ]
      else
        data = auto_mount request: request, development: ENV['RACK_ENV'] == 'development'

        if data.is_a?(Hash)
          [
            data[:status] || 200,
            { 'Content-Type' => 'application/json', 'Cache-Control'=>'private; max-age=0' },
            [data.to_json]
          ]
        else
          data = data.to_s
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
    def auto_mount api_host:, mount_on: nil, bearer: nil, development: false
      request  = api_host.request
      response = api_host.response

      mount_on ||= OPTS[:api][:mount_on] || '/'
      mount_on   = [request.base_url, mount_on].join('') unless mount_on.to_s.include?('//')

      if request.url == mount_on && request.request_method == 'GET'
        response.header['Content-Type'] = 'text/html' if response

        Doc.render request: request, bearer: bearer
      else
        response.header['Content-Type'] = 'application/json' if response

        body     = request.body.read.to_s
        body     = body[0] == '{' ? JSON.parse(body) : nil

        # class: klass, params: params, bearer: bearer, request: request, response: response, development: development
        opts = {}
        opts[:api_host]    = api_host
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

          @@after_auto_mount.call parts, opts if @@after_auto_mount

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

    # renders api doc or calls api class + action
    def render action = nil, opts = {}
      if action
        unless action[0]
          return error 'Action not defined'
        end
      else
        return RenderProxy.new self
      end

      api_class = if klass = opts.delete(:class)
        # /api/_/foo
        if klass == '_'
          klass = Joshua::PostmanSchema.new(opts)

          if klass.respond_to?(action.first)
            return klass.send action.first.to_sym
          else
            return error 'Action %s not defined' % action.first
          end
        end

        klass = klass.split('/') if klass.is_a?(String)
        klass[klass.length-1] += '_api'
        klass = klass.join('/').classify

        begin
          klass.constantize
        rescue NameError => e
          return error 'API class "%s" not found' % klass
        end
      else
        self
      end

      api = api_class.new action, **opts
      api.execute_call
    rescue => error
      error_print error if opts[:development]
      Response.auto_format error
    end

    def render_data action, opts = {}
      response = render action, params: opts
      response && (response[:data] || [])
    end

    # rescue_from CustomError do ...
    # for unhandled
    # rescue_from :all do
    #   api.error 500, 'Error happens'
    # end
    # define handled error code and description
    # error :not_found, 'Document not found'
    # error 404, 'Document not found'
    # in api methods
    # error 404
    # error :not_found
    def rescue_from klass, desc=nil, &block
      RESCUE_FROM[klass] = desc || block
    end

    def after_auto_mount &blok
      @@after_auto_mount = blok
    end

    # show and render single error in class error format
    # usually when API class not found
    def response_error text
      out = Response.new nil
      out.error text
      out.render
    end

    # class errors, raised by params validation
    def error desc
      raise Joshua::Error, desc
    end

    def error_print error
      puts
      puts 'Joshua error dump'
      puts '---'
      puts '%s: %s' % [error.class, error.message]
      puts '---'
      puts error.backtrace
      puts '---'
    end

    # sets api mount point
    # mount_on '/api'
    def mount_on what
      OPTS[:api][:mount_on] = what
    end

    # if you want to make API DOC public use "documented"
    def documented
      if self == Joshua
        DOCUMENTED.sort.uniq.map(&:constantize)
      else
        DOCUMENTED.push to_s unless DOCUMENTED.include?(to_s)
      end
    end

    def api_path
      to_s.underscore.sub(/_api$/, '')
    end

    # define method annotations
    # annotation :unsecure! do
    #   @is_unsecure = true
    # end
    # unsecure!
    # def login
    #   ...
    def annotation name, &block
      ANNOTATIONS[name] = block
      self.define_singleton_method name do |*args|
        unless @method_type
          error 'Annotation "%s" defined outside the API method blocks (member & collections)' % name
        end

        @@opts[:annotations] ||= {}
        @@opts[:annotations][name] = args
      end
    end

    # aleternative way to define a api function
    # members do
    #   define :foo do
    #     params {}
    #     proc {}
    #   end
    # end
    def define name, &block
      func = class_exec &block

      if func.is_a?(Proc)
        self.define_method(name, func)
      else
        raise 'Member block has to return a Func object'
      end
    end

    # /api/companies/1/show
    def member &block
      @method_type = :member
      func = class_exec &block
      @method_type = nil
    end
    alias :members :member

    # /api/companies/list?countrty_id=1
    def collection &block
      @method_type = :collection
      class_exec &block
      @method_type = nil
    end
    alias :collections :collection

    # params do
    #   name? String
    #   email :email
    # end
    def params &block
      raise ArgumentError.new('Block not given for Joshua API method params') unless block_given?

      @@opts[:_typero] = Typero.schema &block
      @@opts[:params] = @@opts[:_typero].to_h
    end

    # api method icon
    # you can find great icons at https://boxicons.com/ - export to svg
    def icon data
      if @method_type
        raise ArgumentError.new('Icons cant be added on methods')
      else
        set :opts, :icon, data
      end
    end

    # api method description
    def desc data
      if @method_type
        @@opts[:desc] = data
      else
        set :opts, :desc, data
      end
    end

    # api method detailed description
    def detail data
      return if data.to_s == ''

      if @method_type
        @@opts[:detail] = data
      else
        set :opts, :detail, data
      end
    end

    # allow alternative method access
    # allow :get
    # if defined, access will be allowed via POST + allowed method
    def allow type
      if @method_type
        type = type.to_s.to_sym

        unless %i(get head post put patch delete trace).include?(type)
          raise ArgumentError.new('"%s" is not allowed http method type' % type)
        end

        @@opts[:allow] = type.to_s.upcase
      else
        raise ArgumentError.new('allow can only be set on methods')
      end
    end

    # define response content type (defaults to JSON)
    def content_type name
      if name.is_class == Symbol
        name = case name
        when :json
          'application/json'
        when :text
          'text/plain'
        else
          raise ArgumentError.new('content-type "%s" is not recognized')
        end
      end

      @@opts[:content_type] = name
    end

    # allow methods without @api.bearer token set
    def unsafe
      if @method_type
        @@opts[:unsafe] = true
      else
        raise ArgumentError.new('Only api methods can be unsafe')
      end
    end

    # block execute before any public method or just some member or collection methods
    def before &block
      set_callback :before, block
    end

    # block execute after any public method or just some member or collection methods
    # used to add meta tags to response
    def after &block
      set_callback :after, block
    end

    # simplified module include, masked as plugin
    # Joshua.plugin :foo do ...
    # Joshua.plugin :foo
    def plugin name, &block
      if block_given?
        # if block given, define a plugin
        PLUGINS[name] = block
      else
        # without a block execute it
        blk = PLUGINS[name]
        raise ArgumentError.new('Plugin :%s not defined' % name) unless blk
        instance_exec &blk
      end
    end

    def get *args
      opts.dig *args
    end

    # dig all options for a current class
    def opts
      out = {}

      # dig down the ancestors tree till Object class
      ancestors.each do |klass|
        break if klass == Object

        # copy all member and collection method options
        keys = (OPTS[klass.to_s] || {}).keys
        keys.each do |type|
          for k, v in (OPTS.dig(klass.to_s, type) || {})
            out[type] ||= {}
            out[type][k] ||= v
          end
        end
      end

      out
    end

    # propagate to typero
    def model name, &block
      Typero.schema name, &block
    end

    # here we capture member & collection metods
    def method_added name
      return if name.to_s.start_with?('_api_')
      return unless @method_type

      set @method_type, name, @@opts

      @@opts = {}

      alias_method "_api_#{@method_type}_#{name}", name
      remove_method name
    end

    def make_hash_html_safe hash
      (hash || {}).each do |k, v|
        if v.is_a?(Hash)
          make_hash_html_safe v
        elsif v.class == String
          hash[k] = v.gsub('<', '#LT;')
        end
      end
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

    # generic opts set
    # set :user_name, :email, :baz
    def set *args
      name, value   = args.pop(2)
      args.unshift to_s
      pointer = OPTS

      for el in args
        pointer[el] ||= {}
        pointer = pointer[el]
      end

      pointer[name] = value
    end
  end
end
