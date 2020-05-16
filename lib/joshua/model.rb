class Joshua
  class Model
    def initialize
      @data = {}
    end

    def method_missing name, *args
      set name, *args
    end

    def set name, type=:string
      @data[name] = type.to_s.underscore.to_sym
    end

    def each &block
      @data.each &block
    end
  end
end