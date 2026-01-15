require_relative '../loader'

describe 'define block syntax' do
  before(:all) do
    class DefineTestApi < ApplicationApi
      collection do
        define :simple_define do
          proc { 'simple' }
        end

        define :with_params do
          params do
            name String
            age? Integer
          end
          proc do
            { name: params.name, age: params.age }
          end
        end

        define :with_desc do
          desc 'A described method'
          detail 'More details here'
          proc { 'described' }
        end

        define :with_annotations do
          unsafe
          proc { @api.opts.unsafe }
        end
      end

      member do
        define :member_define do
          proc { "member_#{@api.id}" }
        end

        define :with_allow do
          allow :get
          proc { 'allowed' }
        end
      end
    end
  end

  it 'works with simple define block' do
    response = DefineTestApi.render :simple_define
    expect(response[:success]).to eq(true)
    expect(response[:data]).to eq('simple')
  end

  it 'works with params in define block' do
    response = DefineTestApi.render :with_params, params: { name: 'John', age: 30 }
    expect(response[:success]).to eq(true)
    expect(response[:data][:name]).to eq('John')
    expect(response[:data][:age]).to eq(30)
  end

  it 'validates required params in define block' do
    response = DefineTestApi.render :with_params, params: { age: 30 }
    expect(response[:success]).to eq(false)
  end

  it 'stores desc and detail from define block' do
    opts = DefineTestApi.opts
    expect(opts[:collection][:with_desc][:desc]).to eq('A described method')
    expect(opts[:collection][:with_desc][:detail]).to eq('More details here')
  end

  it 'works with unsafe annotation in define block' do
    opts = DefineTestApi.opts
    expect(opts[:collection][:with_annotations][:unsafe]).to eq(true)
  end

  it 'works with member define block' do
    response = DefineTestApi.render :member_define, id: 123
    expect(response[:success]).to eq(true)
    expect(response[:data]).to eq('member_123')
  end

  it 'stores allow from define block' do
    opts = DefineTestApi.opts
    expect(opts[:member][:with_allow][:allow]).to eq('GET')
  end

  it 'existing define in CompanyApi works' do
    response = CompanyApi.render.foo(1, bar: 5)
    expect(response[:data]).to eq(15)
  end
end
