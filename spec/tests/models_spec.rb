require_relative '../loader'

describe Joshua do
  let!(:name) { 'acme gmbh' }

  context 'company' do
    it 'gets valid collection url' do
      response = CompanyApi.render.update(1, company: { name: name, address: 'nowhere 123' })
      expect(response[:data][:name]).to eq(name)
    end

    it 'strips out undefined fileds' do
      response = CompanyApi.render.update(1, company: { name: name, not_defined: 'nowhere 123' })
      expect(response[:data][:name]).to eq(name)
      expect(response[:data][:address]).to eq(nil)
      expect(response[:data][:not_defined]).to eq(nil)
    end
  end

  context 'user' do
    it 'rejects bad email in user model' do
      response = UserApi.render.update(1, user: { name: name, email: 'bad email' })
      expect(response[:success]).to eq(false)
    end

    it 'passes with good email' do
      response = UserApi.render.update(1, user: { name: name, email: 'better@email.com' })
      expect(response[:success]).to eq(true)
    end
  end
end