require_relative '../loader'

describe 'tesing params' do
  let!(:parse) { Joshua::Params::Parse.new }

  context 'global checks and' do
    it 'raises error on not existing required attribute' do
      expect { parse.check :integer, nil, req: true }.to raise_error Joshua::Error
      expect { parse.check :wtf, true }.to raise_error StandardError
    end
  end

  context 'validates' do
    it 'boolean' do
      expect(parse.check :boolean, true).to eq true
      expect(parse.check :boolean, 'true').to eq true
      expect(parse.check :boolean, 'false').to eq false
      expect(parse.check :boolean, 1).to eq true
      expect(parse.check :boolean, 'on').to eq true
      expect(parse.check :boolean, nil, default: false).to eq false
      expect { parse.check :boolean, 'aaa' }.to raise_error Joshua::Error
    end

    it 'integer' do
      expect(parse.check :integer, 123).to eq 123
      expect(parse.check :integer, '123').to eq 123
      expect(parse.check :integer, 0).to eq 0
      expect(parse.check :integer, '0').to eq 0
      expect { parse.check :integer, nil, req: true }.to raise_error Joshua::Error
      expect(parse.check :integer, nil).to eq nil
      expect(parse.check :integer, nil, default: 1).to eq 1

      expect { parse.check :integer, 100, max: 99  }.to raise_error Joshua::Error
      expect { parse.check :integer, 99,  min: 100 }.to raise_error Joshua::Error
    end

    it 'string' do
      expect(parse.check :string, 123).to eq '123'
      expect(parse.check :string, ' 123 ').to eq '123'
      expect(parse.check :string, nil, default: '').to eq ''
    end

    it 'float' do
      expect(parse.check :float, '1.2345').to eq 1.2345
      expect(parse.check :float, 1.2345).to eq 1.2345
      expect(parse.check :float, 1.2345, round: 2).to eq 1.23
      expect(parse.check :float, nil, round: 2).to eq nil

      expect { parse.check :float, 100, max: 99  }.to raise_error Joshua::Error
      expect { parse.check :float, 99,  min: 100 }.to raise_error Joshua::Error
    end

    it 'date' do
      expect(parse.check :date, '1.2.2345.').to eq DateTime.parse('1.2.2345.')
      expect(parse.check :date, '1.2.2345. 13:34').to eq DateTime.parse('1.2.2345.')
      expect { parse.check :date, '1.2.2345.', min: '1.2.3345.' }.to raise_error Joshua::Error
      expect { parse.check :date, '1.2.2345.', max: '1.2.1345.' }.to raise_error Joshua::Error
    end

    it 'date_time' do
      expect(parse.check :date_time, '1.2.2345.').to eq DateTime.parse('1.2.2345.')
      expect(parse.check :date_time, '1.2.2345. 13:34').to eq DateTime.parse('1.2.2345 13:34')
      expect { parse.check :date, '1.2.2345.', min: '1.2.3345.' }.to raise_error Joshua::Error
      expect { parse.check :date, '1.2.2345.', max: '1.2.1345.' }.to raise_error Joshua::Error
    end

    it 'hash' do
      expect(parse.check :hash, { foo: 'bar' }).to eq({ foo: 'bar' })
      expect(parse.check :hash, { foo: 'bar', bar: 'baz' }, allow: [:foo]).to eq({ foo: 'bar' })
    end
  end

  context 'various checks as' do
    it 'array option in integer' do
      expect(parse.check :integer, ['1', '2'], array: true).to eq [1, 2]
    end

    it 'checks values in params' do
      expect(parse.check :string, 'red', values: ['red', 'green', 'blue']).to eq 'red'
      expect { parse.check :string, 'red', values: ['green', 'blue'] }.to raise_error Joshua::Error
    end
  end

  context 'api params' do
    it 'expects params to be string by default' do
      params   = UserApi.opts[:collection][:login][:params]
      expected = { required: true, type: :string }

      expect(params[:user]).to eq(expected)
      expect(params[:pass]).to eq(expected)
    end

    it 'expects to fail with bad user and pass' do
      response = UserApi.render :login, params: { user: :a, pass: :b }
      expect(response[:success]).to eq(false)
    end

    it 'expects to report missing parameters' do
      response = UserApi.render :login
      expect(response[:error][:details]).to eq({
        user: 'Argument missing',
        pass: 'Argument missing'
      })
    end

    it 'expects to pass with good user and pass' do
      response = UserApi.render :login, params: { user: :foo, pass: :bar }
      expect(response[:success]).to eq(true)
    end

    it 'expects to pass all params when no params are defined' do
      data   = { foo: 'bar', baz: true }
      result = GenericApi.render :param_test_1, params: data
      expect(result[:data]).to eq(data)
    end
  end

  context 'custom types & array types' do
    it 'cecks if array and set params are working' do
      list = ['foo', 'bar', 'bar', 'b a z']
      response = CleanHash.new GenericApi.render.list_labels(labels_dup: list, labels_nodup: list)
      expect(response.data.labels_dup).to eq(["foo", "bar", "bar", "b_a_z"])
      expect(response.data.labels_nodup).to eq(["foo", "bar", "b_a_z"])
    end
  end
end

