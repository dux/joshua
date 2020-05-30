require 'date'

class Joshua
  module Params
    class Parse
      # params.is_active :boolean, default: false
      def check_boolean value, opts={}
        return false unless value

        if %w(true 1 on).include?(value.to_s)
          true
        elsif %w(false 0 off).include?(value.to_s)
          false
        else
          error 'Unsupported boolean param value: %s' % value
        end
      end

      def check_integer value, opts={}
        value.to_i.tap do |test|
          error localized(:not_integer) if test.to_s != value.to_s
          error localized(:min_value) % opts[:min] if opts[:min] && test < opts[:min]
          error localized(:max_value) % opts[:max] if opts[:max] && test > opts[:max]
        end
      end

      def check_string value, opts={}
        value
          .to_s
          .sub(/^\s+/, '')
          .sub(/\s+$/, '')
      end

      def check_float value, opts={}
        value =
        if opts[:round]
          value.to_f.round(opts[:round])
        else
          value.to_f
        end

        error localized(:min_value) % opts[:min] if opts[:min] && value < opts[:min]
        error localized(:max_value) % opts[:max] if opts[:max] && value > opts[:max]

        value
      end

      def check_date value, opts={}
        date = DateTime.parse(value)
        date = DateTime.new(date.year, date.month, date.day)

        check_date_min_max date, opts
      end

      def check_date_time value, opts={}
        date = DateTime.parse(value)
        check_date_min_max date, opts
      end

      def check_hash value, opts={}
        value = {} unless value.is_a?(Hash)

        if opts[:allow]
          for key in value.keys
            value.delete(key) unless opts[:allow].include?(key)
          end
        end

        value
      end

      def check_email email, opts={}
        error localized(:email_min) unless email.to_s.length > 7
        error localized(:email_missing) unless email.include?('@')
        email.downcase
      end

      def check_url url
        error localized(:url_start) unless url =~ /^https?:\/\/./
        url
      end

      # geolocation point. google maps url will be automaticly converted
      # https://www.google.com/maps/@51.5254742,-0.1057319,13z
      def check_point value, opts={}
        parts = value.split(/\s*,\s*/) unless parts.is_a?(Array)

        error localized(:point_format) unless parts[1]

        for part in parts
          error localized(:point_format) unless part.include?('.')
          error localized(:point_format) unless part.length > 5
        end

        parts.join(',')
      end

      def check_oib oib, opts={}
        oib = oib.to_s

        return false unless oib.match(/^[0-9]{11}$/)

        control_sum = (0..9).inject(10) do |middle, position|
          middle += oib.at(position).to_i
          middle %= 10
          middle = 10 if middle == 0
          middle *= 2
          middle %= 11
        end

        control_sum = 11 - control_sum
        control_sum = 0 if control_sum == 10

        if control_sum == oib.at(10).to_i
          oib.to_i
        else
          error 'Wrong OIB'
        end
      end

      def check_model model, opts
        model_name   = opts[:model].to_s.underscore
        model_schema = MODELS[model_name]

        error "Joshua model for [#{model_name}] not found" unless model_schema

        types, func = *model_schema

        parse = Joshua::Params::Parse.new

        {}.to_hwia.tap do |out|
          for key, type in types
            out[key] = parse.check type, model[key]
          end

          instance_exec(out, &func) if func
        end
      end

      private

      def check_date_min_max value, opts={}
        if min = opts[:min]
          min = DateTime.parse(min)
          error localized(:min_date) % min if min > value
        end

        if max = opts[:max]
          max = DateTime.parse(max)
          error localized(:max_date) % max if value > max
        end

        value
      end

      def localized error
        locale =
        if defined?(Lux)
          Lux.current.locale.to_s
        elsif defined?(I18n)
          I18n.with_locale || I18n.locale
        else
          :en
        end

        pointer = ERRORS[locale.to_sym] || ERRORS[:en]
        pointer[error]
      end
    end
  end
end
