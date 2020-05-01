class Joshua
  module Params
    class Define
      def initialize
        @opts = { }
      end

      def method_missing name, *args
        name = name.to_s

        raise ArgumentError.new('! is not allowed in params') if name.include?('!')

        type, opts = args

        if type.is_a?(Hash)
          opts = args.first
          type = :string
        end

        type = :string if type.nil?

        opts ||= {}
        opts[:type] = type.to_s.dasherize.downcase.to_sym

        opts[:required] = true if opts[:required].nil?
        opts[:required] = false if name.sub! /\?$/, ''
        opts[:required] = false if opts.delete(:optional)

        opts.merge!(type: :boolean, default: false) if opts[:type] == :false
        opts.merge!(type: :boolean, default: true) if opts[:type] == :true
        opts[:required] = false if opts[:type] == :boolean

        @opts[:params] ||= {}
        @opts[:params][name.to_sym] = opts
      end

      def fetch_and_clear_opts
        @opts
          .dup
          .tap { @opts = {} }
      end

      def __add name, value=true
        @opts[name] = value
      end

      def __add_annotation name, data
        @opts[:annotations] ||= {}
        @opts[:annotations][name] = data
      end
    end
  end
end