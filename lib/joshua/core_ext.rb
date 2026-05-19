# Minimal blank?/present? polyfill so Joshua + Typero work without
# pulling in ActiveSupport. Defined conditionally - if the host app
# already provides these (e.g. via Rails / AS), we leave them alone.

class Object
  def blank?;   !self      end unless method_defined?(:blank?)
  def empty?;   blank?     end unless method_defined?(:empty?)
  def present?; !blank?    end unless method_defined?(:present?)
end

class NilClass
  def blank?;   true       end unless method_defined?(:blank?)
  def empty?;   true       end unless method_defined?(:empty?)
  def present?; false      end unless method_defined?(:present?)
end

class FalseClass
  def blank?;   true       end unless method_defined?(:blank?)
end

class TrueClass
  def blank?;   false      end unless method_defined?(:blank?)
end

class Array
  def blank?;   length == 0 end unless method_defined?(:blank?)
end

class Hash
  def blank?;   keys.length == 0 end unless method_defined?(:blank?)
end

class Numeric
  def blank?;   false      end unless method_defined?(:blank?)
end

class Time
  def blank?;   false      end unless method_defined?(:blank?)
end

class String
  unless method_defined?(:blank?)
    def blank?
      return true if length == 0
      !(self =~ /[^\s]/)
    end
  end
end
