class Joshua
  class Exporter
    EXPORTERS     ||= {}

    @@export_depth = 1

    class << self
      def export_depth depth=nil
        @@export_depth = depth if depth
        @@export_depth
      end

      def define name, opts={}, &block
        opts[:include_missing] = true if opts.delete(:nil)

        EXPORTERS[name.to_s.underscore] = [block, opts]
      end

      def export object, opts={}
        return if depth > @@export_depth
        klass = opts.delete(:exporter) || object.class
        klass = klass.to_s.underscore
        func  = EXPORTERS[klass] || raise('Exporter %s not defined, you have: %s' % [klass, EXPORTERS.keys.join(', ')])

        depth 1
        out = {}
        begin
          func.first.call object, out
          depth -1
        rescue => error
          return { error: [error.class.to_s, error.message]}
        ensure
          Thread.current[:joshua_export_depth] = 0
        end
        out
      end

      def depth num=nil
        Thread.current[:joshua_export_depth] ||= 0
        Thread.current[:joshua_export_depth] += num if num
        Thread.current[:joshua_export_depth]
      end
    end

    ###

    def initialize

    end

    # get current user from globals if globals defined
    def user
      if @user
        @user
      elsif defined?(User) && User.respond_to?(:current)
        User.current
      elsif defined?(Current) && Current.respond_to?(:user)
        Current.user
      elsif current_user = Thread.current[:current_user]
        current_user
      else
        raise RuntimeError.new('Current user not found, define it in Joshua::Exporter#user')
      end
    end
  end
end