# Clean API

CleanAPI is opinionated [API](https://learn.g2.com/api) implementation for [Ruby](https://www.ruby-lang.org/en/) based clients, featuring automount for [rack](https://github.com/rack/rack) based clients.

### Main features

* Nearly nothing to learn, pure Ruby clases
* Automatic routing
* Automatic documentation builder & Postman import link
* Can work in REST or JSON RPC mode.
* Consistent and predictable request and response flow

<br />

### Annotated example

Featuring all you have to know to start building your APIs using CleanAPI (you don't even have to read rest of the documentation :)


```ruby
# in ApplicationApi we will define rules that will reflect all other API classes
class ApplicationAPI < CleanAPI
  # Inside ot the methods you can say `error :foo` and text error will raise
  rescue_from :foo, 'Baz is angry'

  # Capture Policy::Error and add custom formating
  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  # Define method annotation that will be run before the method executes
  annotation :anonymous do
    @anonymous_allowed = true
  end

  # Define custom paramter called label
  # that will allow only characters, with max length of 15
  params :label do |value, opts|
    error 'Label is not in the right format' unless value =~ /^\w{1,15}$/
  end

  # Thisd before block wil be executed before any method call
  before do
    # If token provided load user, raise error otherwise
    if @api.bearer
      @current_user = User.find_by token: @api.bearer 
      
      # raise unless user found
      error 'Invalid API token' unless @current_user
    end
    
    # raise error unless @user defined and we dot allow anonymous access
    if !@user && !@anonymous_allowed
      error 'Anonymous access not allowed,please register'
    end

    # we will use this time to calcualte method execution speed
    @_time = Time.now
  end

  # this will be run after the method executes
  after do
    # add meta tag request.ip if request object is available
    response[:ip] = @api.request ? @api.request.ip : '1.2.3.4'

    # add meta tag speed in ms
    response[:speed] = ((Time.now - @_time)*1000).round(3)
  end

  # `user` method will be available in member and collection methods
  def user
    # Raise and return error if user requested but not found
    @current_user || error('User not loaded')
  end
end


# We will create generic ModelAPI, that all models will inherit from
class ModelAPI < ApplicationAPI
  # Define member methods (ones that have object IDs)
  member do

    # Eexecute before running member methods (show, update, delete, ...)
    # that inherit from ModelAPI
    before do
      
      # load generic object based on current class name
      # UsersApi -> User
      base = self
        .class
        .to_s
        .sub(/Api$/, '')
        .singularize
        .constantize

      # try to load the object
      @model = base.find(@api.id)

      # raise error unless object not found
      error 404, 'Object %s[%s] is not found' % [base, @api.id] unless @model
    end

    # Execute after method exection, only in member methods
    after do
      # add object path to response
      response[:path] = @model.path
    end
  end
end


# Example API class for User model
class UsersApi < ModelAPI
  # Document this class in various documentations
  documented

  # Define methods for methods that do not need id
  collection do
    # Describe the method
    desc 'Signup via email to app'
    # Define email param, with type of email
    params.email! :email

    # Define "/api/users/signup" method
    # info: collection methods do not have an ID
    def signup
      # Deliver magic login link
      Mailer.email_login_magic_link(params.email).deliver
      
      # Add response message
      message 'Email with login link sent'
    end

    params do
      # method name in a block is paramter name, and it is required
      user String, required: true
      # if you add bang, it is required
      pass! String 
    end
    def login
      if params.user == 'foo' && params.pass == 'bar'
        User.first.token
      else
        error 'Wrong user or pass'
      end
    end
  end

  member do
    before do
      @user = @model

      # Unless user is admin
      unless user.can.admin?
        # do not allow him to access member methods in UsersApi class
        if @user.id != user.id
          error('This is not you! Hack attempt logged :)') 
        end
      end
    end

    # allow access via GET
    allow :get
    # /api/users/:id/show
    def show
      # export object hash
      @user.api_export
    end

    # /api/users/:id/show
    def delete
      @user.destroy
      message 'You deleted yourself'
    end

    desc 'Generate new user access token'
    # /api/users/:id/re_tokenize
    def re_tokenize
      @user.update token: Crypt.random(40)
      messsage 'New token generated'
    end
  end
end


# Example api call with response
UserApi.call :login, params: { user: 'foo', pass: 'bar' }
# {
#   success: true,
#   message: 'login ok',
#   meta: { ip: '127.0.0.1' }
# }

UserApi.call :login, params: { user: 'aaa', pass: 'bbb' }
# {
#   success: false,
#   error: {
#     messages: ['Wrong user or pass']
#   },
#   meta: { ip: '127.0.0.1' }
# }
```

<br />

### Main features in detail

* **Can work in REST or JSON RPC mode.**
  <br />
  adadasdad

* **Can work in REST or JSON RPC mode.**
  <br />
  By default API works on POST, but you can modify the behaviour by enabling specific method 

* **Automatic routing**
  <br />
  Because requests are mapped to ruby methods. Result is 

* **Automatic documentation builder**
  <br />
  Beautiful documentation is automaticly build for you, with redy libraries for all popular languages

* **Nothing to learn**
  <br />
  pure Ruby clases. CleanAPI is based on plain Ruby with using before and after filters similar to Rails controllers.
  `'/api/v1/orgs/list' # V1::OrgsApi.call(:list)`

* **Consistent and predictable request and response flow**
  <br />


## Params

You can define params directly on the parmas object or you can pass a block

* every param can have `default:` value if `blank?`
* every param can have `required: true` of default `false` (shorcut `req:`)
* param errors are [localized](./params/type_errors.rb)

```ruby
params do
  # withot params defaults to String, required: false
  full_name
  full_name String, { required: false }    # the same default

  # if you add bang, it becomes required true
  full_name! # String, { required: true}  # the same

  # supported types with options
  # boolean
  activated :boolean # { type: :boolean, default: false }
  # you can define boolean with default value
  activated false    # { type: :boolean, default: false }
  activated true     # { type: :boolean, default: true }

  # other
  amount  Float, { min: [5, '$5 is minimal purchase'], max: 500 }
  date1   Date      # { min: ..., max: ... }
  date2   DateTime  # { min: ..., max: ... }
  count   Integer   # { min: ..., max: ... }
  weight  Float     # { min: ..., max: ... }
  email   :email
  email   :url
end
```