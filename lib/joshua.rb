unless ''.respond_to?(:classify)
  require 'sequel'
  Sequel.extension :inflector
end

require_relative './joshua/core_ext'

require 'json'
require 'typero'
require 'hash_wia'

require_relative './joshua/base_instance'
require_relative './joshua/base_class'
require_relative './joshua/response'
require_relative './joshua/render_proxy'
require_relative './joshua/introspect'
require_relative './joshua/web'
require_relative './joshua/file_response'

require_relative './doc/postman_schema'
require_relative './doc/openapi_schema'

require_relative './joshua/sys_api'



