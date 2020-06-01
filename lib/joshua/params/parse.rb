class Joshua
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
            error 'Argument missing'
          end
        else
          if opts[:array]
            unless value.is_a?(Array)
              delimiter   = opts[:delimiter] || /\s*[,:;]\s*/
              value = value.split(delimiter)
            end

            value = value.map { |_| check_send type, _, opts }
            value = Set.new(value).to_a if opts[:no_duplicates]
            value
          else
            check_send type, value, opts
          end
        end
      end

      private

      def check_send type, value, opts
        type_check = 'check_%s' % type
        result =
        if respond_to?(type_check)
          send(type_check, value, opts)
        elsif Object.const_defined?('Typero') && Typero.defined?(type)
          begin
            Typero.set(type, value, opts)
          rescue TypeError => err
            error err.message
          end
        else
          hard_error 'Unsupported paramter type: %s' % type
        end

        error localized(:not_in_range) if opts[:values] && !opts[:values].include?(result)

        result
      end

      def error desc
        raise Joshua::Error, desc
      end

      def hard_error desc
        raise StandardError, desc
      end
    end
  end
end
