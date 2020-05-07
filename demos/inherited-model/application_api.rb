class ApplicationApi < Joshua
  annotation :hcaptcha! do
    captcha = params['h-captcha-response'] || error('Captcha not selected')
    data    = JSON.parse `curl -d "response=#{captcha}&secret=#{Lux.secrets.hcaptcha.secret}" -X POST https://hcaptcha.com/siteverify`
  
    unless data['success']
      error 'HCaptcha error: %s' % data['error-codes'].join(', ') 
    end
  end

  before do
    # load user if token provided
    if @api.bearer
      User.current = User.find_by token: @api.bearer
      error 'Invalid API token' unless User.current
    end
  end

  def user
    User.current || error('User session is required to perform the action')
  end
end
