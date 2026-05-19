class UserApi < ApplicationApi
  documented
  class_desc 'Users and auth'
  icon 'person'

  desc   'Log in with user + pass'
  detail "Demo users: foo/bar -> token 'demo-token'. Bad creds return 401."
  params do
    user String, required: true
    pass String, required: true
  end
  unsafe
  def login
    if params.user == 'foo' && params.pass == 'bar'
      message 'logged in'
      { token: 'demo-token' }
    else
      response.error 'bad credentials', status: 401
    end
  end

  desc 'Echo the bearer token used in this request'
  allow :get
  def me
    { bearer: @api.bearer || '(none)' }
  end
end
