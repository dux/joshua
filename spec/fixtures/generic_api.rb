require_relative 'module'

class GenericApi < ApplicationApi
  include ApiModuleClasic
  plugin :test_1

  documented

  icon   '<circle fill="none" cx="17.5" cy="18.5" r="1.5"/><circle fill="none" cx="5.5" cy="11.5" r="1.5"/><circle fill="none" cx="17.5" cy="5.5" r="1.5"/><path d="M5.5,15c0.91,0,1.733-0.358,2.357-0.93l6.26,3.577C14.048,17.922,14,18.204,14,18.5c0,1.93,1.57,3.5,3.5,3.5 s3.5-1.57,3.5-3.5S19.43,15,17.5,15c-0.91,0-1.733,0.358-2.357,0.93l-6.26-3.577c0.063-0.247,0.103-0.502,0.108-0.768l6.151-3.515 C15.767,8.642,16.59,9,17.5,9C19.43,9,21,7.43,21,5.5S19.43,2,17.5,2S14,3.57,14,5.5c0,0.296,0.048,0.578,0.117,0.853L8.433,9.602 C7.808,8.64,6.729,8,5.5,8C3.57,8,2,9.57,2,11.5S3.57,15,5.5,15z M17.5,17c0.827,0,1.5,0.673,1.5,1.5S18.327,20,17.5,20 S16,19.327,16,18.5S16.673,17,17.5,17z M17.5,4C18.327,4,19,4.673,19,5.5S18.327,7,17.5,7S16,6.327,16,5.5S16.673,4,17.5,4z M5.5,10C6.327,10,7,10.673,7,11.5S6.327,13,5.5,13S4,12.327,4,11.5S4.673,10,5.5,10z"/>'
  desc   'Simple generic api'
  detail '<p>Nothing <b>specific</b>.</p>'

  collection do
    def about
      2 * xxx
    end

    def get_money
      error 405
    end

    desc 'This will just return ok'
    detail 'No need for big details'
    def all_ok
      'ok'
    end

    def param_test_1
      params.to_h
    end

    desc 'Passing params'
    detail "This will just pass params\n\n* first item\n* second item"
    params do
      abc! default: :baz
      foo String, req: true, default: :baz
      bar
    end
    def param_test_2
      params.to_h
    end

    anonymous
    def anon_test
      @anonymous_ok
    end
  end
end