require_relative '../loader'
require_relative '../../lib/joshua/client'

describe 'dev' do
  let (:api) { JoshuaClient.new 'http://localhost:4567/api' }

  it 'tests valid collection methods params' do
    ap api
  end
end