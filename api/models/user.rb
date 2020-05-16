class ApplicationApi

  model :user do |m|
    name     String
    email    :email
    is_admin :boolean

    proc do |data|
      error 'You cant edit :is_admin attribute' if !data[:is_admin].nil? && data[:name] == 'john'
    end
  end

end