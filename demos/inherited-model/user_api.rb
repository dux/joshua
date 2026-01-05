class UsersApi < ModelApi
  documented

  generate :show
  generate :update

  collection do
    define :signup do
      desc 'Signup via email to app'
      hcaptcha!
      params do
        email :email
      end
      proc do
        Mailer.email_login(params.email).deliver
        'Email with login link sent'
      end
    end

    define :list do
      prod do

      end
    end
  end

  member do
    before do
      unless user.can.admin?
        error('This is not you! Hack attempt logged :)') if @user.id != user.id
      end
    end

    ###

    define :delete do
      desc 'Delete user by disabling it'
      proc do
        @user.update is_deleted: true, name: 'DELETED BY USER'
        message 'You deleted a user'
      end
    end

    define :undelete do
      desc 'Undelete user by enableing it'
      proc do
        @user.update is_deleted: false, name: params.name
        message 'You undeleted a user'
      end
    end

    # or defined as simple proc not via define notation
    desc 'Generate new user access token'
    def re_tokenize
      @user.update token: Crypt.random(40)
      message 'Token updated'
    end
  end
end
