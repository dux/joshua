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
          type_check = 'check_%s' % type
          hard_error 'Unsupported paramter type: %s' % type unless respond_to?(type_check)

          if opts[:array]
            unless value.is_a?(Array)
              delimiter   = opts[:delimiter] || /\s*[,:;]\s*/
              value = value.split(delimiter)
            end

            value = value.map { |_| check_send type_check, _, opts }
            value = Set.new(value).to_a if opts[:no_duplicates]
            value
          else
            check_send type_check, value, opts
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
        raise Joshua::Error, desc
      end

      def hard_error desc
        raise StandardError, desc
      end
    end
  end
end
