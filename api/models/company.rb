class Company < Struct.new(:name, :address)
  def name
    'ACME corp'
  end
end

class ApplicationApi

  model Company do |m|
    m.set :name, String
    m.set :address, String
  end

  export Company do |model, out|
    # raise 'foo' if [1,2,3].sample == 2

    raise 'foo' if model[:name] == 'ERROR'
    
    out[:name]     = model[:name]
    out[:address]  = model[:address]
    out[:filtered] = true
    out[:creator]  = export User.new('mike', 'foo@bar.baz')
  end

end
  