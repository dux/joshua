# Api response is constructed from this object

class CleanApi
  class Response
    def initialize
      @out    = {}
      @meta   = {}
      @errors = {}
    end

    def []= key, value
      meta key, value
    end

    def message value
      @message = value
    end

    def meta key, value = nil
      if value
        @meta[key] = value
      else
        @meta[key]
      end
    end

    def error *args
      return @errors unless args[0]

      desc, code = args.reverse

      @errors[:code]       = code if code
      @errors[:messages] ||= []
      @errors[:messages].push desc unless @errors[:messages].include?(desc)
    end

    def error?
      !!@errors[:messages]
    end

    def error_detail name, desc
      @errors[:details]     ||= {}
      @errors[:details][name] = desc
    end

    def data value
      @data = value
    end

    def data?
      !@data.nil?
    end

    def render
      {}.tap do |out|
        if @errors.keys.empty?
          out[:success] = true
        else
          out[:success] = false
          out[:error] = @errors
        end

        out[:meta]    = @meta
        out[:message] = @message if @message
        out[:data]    = @data unless @data.nil?
      end
    end
  end
end
