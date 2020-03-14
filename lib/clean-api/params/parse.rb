class CleanApi
  module Params
    class Parse
      class << self
        def define name, &block
          define_method 'check_%s' % name do |value, opts|
            block.call value, opts || {}
          end
        end
      end

      ###

      # check :boolean, 'on'
      def check type, value, opts={}
        opts[:required] = true if opts.delete(:req)

        if value.to_s == ''
          if !opts[:default].nil?
            opts[:default]
          elsif opts[:required]
            error 'Argument required'
          end
        else
          m = 'check_%s' % type
          hard_error 'Unsupported paramter type: %s' % type unless respond_to?(m)

          if opts[:array]
            delimiter = opts[:array].is_a?(TrueClass) ? /\s*[,:;]\s*/ : opts[:array]

            value = value.split(delimiter) unless value.is_a?(Array)
            value.map { |_| check_send m, _, opts }
          else
            check_send m, value, opts
          end
        end
      end

      private

      def check_send m, value, opts
        send(m, value, opts).tap do |_|
          error 'Value not in range of values' if opts[:values] && !opts[:values].include?(_)
        end
      end

      def error desc
        raise CleanApi::Error, desc
      end

      def hard_error desc
        raise StandardError, desc
      end
    end
  end
end
