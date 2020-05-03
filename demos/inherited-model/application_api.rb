class ApplicationApi < Joshua
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
