class CleanApi
  class Error < StandardError
  end

  RESCUE_FROM  = {}

  class << self
    # rescue_from CustomError do ...
    # for unhandled
    # rescue_from :all do
    #   api.error 500, 'Error happens'
    # end
    # define handled error code and description
    # error :not_found, 'Document not found'
    # error 404, 'Document not found'
    # in api methods
    # error 404
    # error :not_found
    def rescue_from klass, desc=nil, &block
      RESCUE_FROM[klass] = desc || block
    end
  end

  ###

  def error desc
    if err = RESCUE_FROM[desc]
      if err.is_a?(Proc)
        err.call
      else
        response.error desc, err
        desc = err
      end

      return
    end

    raise CleanApi::Error, desc
  end

end
