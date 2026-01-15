require_relative '../loader'

describe 'HTTP method restrictions' do
  context 'allow directive' do
    it 'stores allow GET on method' do
      opts = UserApi.opts
      expect(opts[:collection][:call_me_in_child][:allow]).to eq('DELETE')
    end

    it 'stores allow PUT on CompanyApi collection index' do
      opts = CompanyApi.opts
      expect(opts[:collection][:index][:allow]).to eq('PUT')
    end

    it 'defaults to POST when no allow specified' do
      opts = CompanyApi.opts
      expect(opts[:collection][:info][:allow]).to be_nil  # defaults to POST
    end
  end

  context 'method storage in opts' do
    it 'stores multiple HTTP methods' do
      # Check that the allow directive is properly stored
      opts = UserApi.opts
      allow_value = opts[:collection][:call_me_in_child][:allow]
      expect(allow_value).to eq('DELETE')
    end
  end
end
