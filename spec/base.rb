require_relative '../lib/clean-api'

require_relative './fixtures/application_api'
require_relative './fixtures/generic_api'
require_relative './fixtures/model_api'
require_relative './fixtures/company_api'
require_relative './fixtures/user_api'

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