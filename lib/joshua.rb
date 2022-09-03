unless ''.respond_to?(:classify)
  require 'sequel'
  Sequel.extension :inflector
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



