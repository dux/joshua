require 'joshua'

class ApplicationApi < Joshua
end

class UsersApi < ApplicationApi
  documented
  
  collection do
    desc   'Login test'
    detail 'user + pass = foo + bar'
    params do
      user
      pass
    end
    def login
      if params.user == 'foo' && params.pass == 'bar'
        message 'Login ok'

        'token-abcdefg'
      else
        error 'Bad user name or pass'
      end
    end
  end
end

run ApplicationApi