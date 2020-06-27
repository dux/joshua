require_relative '../lib/joshua'

require_relative '../api/application_api'
require_relative '../api/generic_api'
require_relative '../api/model_api'
require_relative '../api/company_api'
require_relative '../api/user_api'

require_relative '../api/models.rb'
require_relative '../api/exports.rb'

class Object
  def pp data
    puts
    if data.is_a?(Hash)
      puts JSON.pretty_generate(data)
    else
      ap data
    end
  end
end