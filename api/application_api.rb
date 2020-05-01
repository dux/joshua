class ApplicationApi < CleanApi

  base '/api'

  ###

  rescue_from 405, '$ not found'

  rescue_from :all do |error|
    ap [error.message, error.backtrace.reject{ |_| _.include?('/.rvm/') }] unless ENV['RACK_ENV'] == 'test'

    response.error 500, 'Error happens'
  end

  rescue_from :named_error, 'Named error example'

  ###

  annotation :anonymous do
    @anonymous_ok = 12345
  end

  ###

  params :label do |value, opts|

  end

  ###

  before do
    @_time = Time.now
  end

  after do
    response[:ip] = @api.request ? @api.request.ip : '1.2.3.4'
    response.meta :speed_ms, ((Time.now - @_time)*1000).round(3) unless ENV['RACK_ENV'] == 'test'
  end

end