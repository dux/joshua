class CleanApi
  module Params
    class Define
      def initialize
        @opts = { }
      end

      def method_missing name, *args
        name = name.to_s

        type, opts = args

        if type.is_a?(Hash)
          opts = args.first
          type = :string
        end

        type = :string if type.nil?
        opts ||= {}

        opts[:required] = true if name.sub! /!$/, ''
        opts[:required] = true if opts.delete(:req)

        opts[:type] = type.to_s.dasherize.downcase.to_sym

        opts.merge!(type: :boolean, default: false) if opts[:type] == :false
        opts.merge!(type: :boolean, default: true) if opts[:type] == :true

        # ap({name: name, args: args, opts: opts})

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