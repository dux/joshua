require_relative '../loader'

describe 'dev' do
  let (:opts) { CompanyApi.opts }

  it 'tests valid collection methods params' do
    expect(opts.dig(:collection, :index, :params, :country_id, :type)).to eq :integer
    expect(opts.dig(:collection, :index, :params, :is_active, :type)).to eq :boolean
    expect(opts.dig(:collection, :info)).to eq({})
  end

  it 'tests valid mememer methods params' do
    expect(opts.dig(:member, :index, :params, :is_active)).to eq({ type: :boolean, default: false })
    expect(opts.dig(:member, :show)).to eq({})
  end

  it 'tests valid deep method defines (from parent ModelApi)' do
    expect(opts.dig(:member, :creator, :params)).to eq({:show_all=>{:default=>false, :type=>:boolean}})
  end

  it 'adds method descriptions' do
    expect(opts.dig(:member, :index, :desc)).to eq('Simple index')
    expect(opts.dig(:member, :creator, :desc).length).to eq(21)
  end

  it 'executes before in order' do
    response = CompanyApi.render :index, id: 1, params: { name: 'Dux' }
    expect(response).to eq({success: true, message: 'all ok', meta: { ip: '1.2.3.4' }, data: 'JRNI' })
  end

  it 'expects clasic module to be incuded' do
    response = GenericApi.render :module_clasic
    expect(response).to eq({ data: 'is_module', meta: { ip: '1.2.3.4' }, :success=>true})
  end

  it 'expects plugins to work' do
    response = GenericApi.render :plugin_test
    expect(response).to eq({ data: 'from_plugin', success: true, meta: { ip: '1.2.3.4' }})
  end

  it 'expects csv as a response' do
    response = GenericApi.render :send_csv
    expect(response.split($/).first).to eq('name;email')
  end
end