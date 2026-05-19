class ApplicationApi < Joshua
  mount_on '/api'

  rescue_from :not_found, 'Record not found'

  rescue_from :all do |error|
    response.error error.message, status: 500
  end
end
