class ApplicationApi
  export User do
    prop :name
    prop :email

    prop :is_admin do
      model[:is_admin] ? 'YES' : 'no'
    end

    export :company
  end

  export Company do
    prop :name
    prop :address
    export :creator

    prop :filtered do
      true
    end
  end
end
