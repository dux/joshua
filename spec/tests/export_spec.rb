require_relative '../loader'

describe 'exporter' do
  context 'company' do
    it 'checks name' do
      company = Company.new 'ACME', 'Nowhere 123'
      export  = Joshua.export company
      expect(export[:creator][:name]).to eq('miki')
    end
  end
end