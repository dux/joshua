require_relative '../lib/joshua'

require_relative '../api/application_api'
require_relative '../api/generic_api'
require_relative '../api/model_api'
require_relative '../api/company_api'
require_relative '../api/user_api'

require_relative '../api/models.rb'

class Object
  def pp data
    puts
    if data.is_a?(Hash)
      puts JSON.pretty_generate(data)
    else
      ap data
    end
  end

  def rr data
    puts '- start: %s - %s' % [data.class, caller[0].sub(__dir__+'/', '')]
    ap data
    puts '- end'
  end
end