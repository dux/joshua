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
require 'typero'
require 'html-tag'
require 'hash_wia'

require_relative './joshua/base_instance'
require_relative './joshua/base_class'
require_relative './joshua/response'
require_relative './joshua/render_proxy'

require_relative './doc/doc'
require_relative './doc/special'



