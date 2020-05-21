class User < Struct.new(:name, :email, :is_admin)
end

class ApplicationApi

  model User do |m|
    name     String
    email    :email
    is_admin :boolean

    proc do |data|
      error 'You cant edit :is_admin attribute' if !data[:is_admin].nil? && data[:name] == 'john'
    end
  end

  export User, include_missing: true do |model, out|
    out[:name]     = model[:name]
    out[:email]    = model[:email]
    out[:company]  = export Company.new('ACME', 'Somewhere 123')
    out[:is_admin] = 'YES' || 'no' unless model[:is_admin].nil?
    out[:filtered] = true
  end

end
