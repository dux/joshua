class UsersApi < ModelApi
  documented

  generate :show
  generate :update

  collection do
    desc 'Signup via email to app'
    params.email :email
    recaptcha!
    def signup
      Mailer.email_login(params.email).deliver
      'Email with login link sent'
    end
  end

  member do
    before do
      unless user.can.admin?
        error('This is not you! Hack attempt logged :)') if @user.id != user.id
      end
    end

    ###

    def delete
      @user.update is_deleted: true, name: 'DELETED BY USER'
      message 'You deleted yourself'
    end

    params.name min: 6
    def undelete
      @user.update is_deleted: false, name: params.name
      messsage 'You undeleted yourself'
    end

    desc 'Generate new user access token'
    def re_tokenize
      @user.update token: Crypt.random(40)
      messsage 'Token updated'
    end
  end
end
