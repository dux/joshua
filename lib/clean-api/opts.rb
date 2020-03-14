class CleanApi
  PARAMS        ||= Params::Define.new
  ANNOTATIONS   ||= {}
  OPTS            = {}
  PLUGINS         = {}
  ACTIVATED       = []

  class << self
    def base what
      set :opts, :base, what
    end

    # if you want to make API public use "is_active"
    def is_active
      ACTIVATED.push self unless ACTIVATED.include?(self)
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
        PARAMS.__add_annotation name, args
      end
    end

    # /api/companies/1/show
    def member &block
      @method_type = :member
      class_exec &block
      @method_type = nil
    end

    # /api/companies/list?countrty_id=1
    def collection &block
      @method_type = :collection
      class_exec &block
      @method_type = nil
    end

    # There are multiple ways to create params
    # params :name, String, req: true
    # params.name!, String
    # params do
    #   name String, required: true
    #   name! String
    # end
    # params :label do |value, opts|
    #   # validate is value a label, return coarced label
    #   # or raise error with error
    # end
    def params *args, &block
      if name = args.first
        if block
          # if argument is provided we create a validator
          Params::Parse.define name, &block
        else
          only_in_api_methods!
          PARAMS.send *args
        end
      elsif block
        PARAMS.instance_eval &block
      else
        only_in_api_methods!
        PARAMS
      end
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
        PARAMS.__add_desc data
      else
        set :opts, :desc, data
      end
    end

    # api method detailed description
    def detail data
      if @method_type
        PARAMS.__add_detail data
      else
        set :opts, :detail, data
      end
    end

    # block execute before any public method or just some member or collection methods
    def before &block
      set_callback :before, block
    end

    def after &block
      set_callback :after, block
    end

    # simplified module include, masked as plugin
    # CleanApi.plugin :foo do ...
    # CleanApi.plugin :foo
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

    private

    # generic opts set
    # set :foo, :bar, :baz
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

