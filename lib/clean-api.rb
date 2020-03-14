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

require_relative './clean-api/params/define'
require_relative './clean-api/params/parse'
require_relative './clean-api/params/types'
require_relative './clean-api/params/types_errors'
require_relative './clean-api/opts'
require_relative './clean-api/base'
require_relative './clean-api/error'
require_relative './clean-api/response'
require_relative './clean-api/doc'


