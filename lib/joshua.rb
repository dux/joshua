unless ''.respond_to?(:dasherize)
  require 'dry/inflector'

  class String
    %w(
      classify
      constantize
      dasherize
      ordinalize
      pluralize
      singularize
      tableize
      underscore
    ).each do |name|
      define_method name do
        Dry::Inflector.new.send(name, self)
      end
    end
  end
end

require 'json'
require 'html-tag'
require 'clean-hash'

require_relative './joshua/params/define'
require_relative './joshua/params/parse'
require_relative './joshua/params/types'
require_relative './joshua/params/types_errors'
require_relative './joshua/opts'
require_relative './joshua/base'
require_relative './joshua/error'
require_relative './joshua/response'

require_relative './doc/doc'
require_relative './doc/special'


