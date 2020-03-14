require './lib/clean-api'

require './spec/fixtures/application_api'
require './spec/fixtures/generic_api'
require './spec/fixtures/model_api'
require './spec/fixtures/company_api'
require './spec/fixtures/user_api'

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