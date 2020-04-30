# Clean API

CleanAPI is opinionated [API](https://learn.g2.com/api) implementation for [Ruby](https://www.ruby-lang.org/en/) based clients, featuring automount for [rack](https://github.com/rack/rack) based clients.

### Main features

* Can work in REST or JSON RPC mode.
* Automatic routing
* Automatic documentation builder & Postman import link
* Nearly nothing to learn, pure Ruby clases [&rarr;](#pure)
* Consistent and predictable request and response flow
* errors and messages are [localized](./params/type_errors.rb)

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
  # Eexecute before all methods that inherit from ModelAPI
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
    if @api.id
      @model = base.find @api.id
      error 'Object %s[%s] is not found' % [base, @api.id] unless @model
    else
      @model = base.new
    end

    # raise error unless object not found
    error 404, 'Object %s[%s] is not found' % [base, @api.id] unless @model
  end

  # Execute after method exection, only in member methods
  after do
    # add object path to response
    response[:path] = @model.path
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
    def signup
      # Deliver magic login link
      Mailer.email_login_magic_link(params.email).deliver
      
      # Add response message
      message 'Email with login link sent to %s' % params.email
    end

    # params can be defined as a block as well
    params do
      # method name in a block is paramter name, and it is required
      user String, required: true
      # if you add bang, it is required
      pass! String 
    end
    # /api/users/login
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

## Main features in detail

### Can work in REST or JSON RPC mode

By default API works on POST for all methods, but you can modify the behaviour by enabling specific methods 

```bash
# this POST request will in production by default 
curl -d 'foo=bar' http://localhost:3000/api/orgs/1/show

# or as JSON RPC style POST
curl -d '{"id":"rand","action":["org","1","show"],"params":{"foo":"bar"}}' http://localhost:3000/api

# this will work only in development (GET request)
curl http://localhost:3000/api/orgs/1/show?foo=bar
```

Response is consistent because it is generated from [CleanAPI::Response](https://github.com/dux/clean-api/blob/master/lib/clean-api/response.rb) class 
but you can respond with anything you like

```ruby
  # respond with csv data
  # /api/user/1/send_csv
  def send_csv
    response :csv do
      @user.generate_csv_data
    end
  end
  # Content-type: application/csv
  # name, email, ...

  # response with CSV in response data block
  # /api/user/1/send_csv
  def send_csv
    @user.generate_csv_data
  end
  # Content-type: application/json
  # {
  #   success: true,
  #   data: 'csv data...'
  # }
```

<hr />

### Automatic routing

Requests are directly maped to ruby methods. Example will say it all

Routes can have max 3 elements.

* 2 elements &rarr; class + collection method
* 3 elements &rarr; class + id + member method

```ruby
class UsersApi
  collection do
    def login
      'login'
    end
  end

  member do
    def update
      'update'
    end
  end
end

module Parent
  class Child
    collection do
      def nested
      end
    end
  end
end
```

* Route to access user login method `/api/users/login`
* Route to access user update `/api/users/123/update`
* Route to access nested `/api/parent.child/123/update`.
  <br />
  Note that you separate modules/classes with a dot.

It is possible to have custom routes as `/api/:company/:class/:id/:method` etc but you have to configure that manualy. This is what you get "out of the box" by `CleanAPI.auto_mount`

This is **ALL** you have to know about routing.

<hr />

### Automatic documentation builder

Beautiful documentation is automaticly build for you, with ready libraries for all popular languages.

To enable class documenttion add `documented`

```ruby
class UserApi < CleanAPI
  documented
  # ...
end
```

Assuming that `CleanAPI` mount point is `/api`

* Interactive HTML documentation will be on `/api`
* RAW JSON is available on `/api/_/raw`
* [Postman](https://www.postman.com/) import URL is available on `/api/_/postman`

<hr />

### Consistent and predictable request and response flow

Routing is automatic and response is generated by [CleanAPI::Response](https://github.com/dux/clean-api/blob/master/lib/clean-api/response.rb) class.

<br />

## Specifics and details

### Class methods

Methods avaiable on class level.

#### Rescue from

Similar to Rails `rescue_from`. You can call manualy with `error :foo` or `error 404`, capture named errors and format response as you fit.

```ruby
rescue_from :foo, 'Baz is angry'
# in method
def foo
  error :foo
end

# Capture Policy::Error and add custom formating
rescue_from Policy::Error do |error|
  error 403, 'Policy error: %s' % error.message
end
# in method
def foo
  @user.can.admin! # triggers Policy::Error, gets captured
end
```

#### Annotations

```ruby
# Define method annotation that will be run before the method executes
annotation :anonymous do
  @anonymous_allowed = true
end
```

#### Params

```ruby
# Define custom paramter called label
# that will allow only characters, with max length of 15
params :label do |value, opts|
  error 'Label is not in the right format' unless value =~ /^\w{1,15}$/
end
```

#### Before and after & members and collections

* If defined in root, `before` and `after` filters fill be triggerd on every API method call.
* `member` and `collection` will group API methods that.

```ruby
class UserAPI < CleanAPI
  # Thisd before block wil be executed before any method call
  before do
    @num = 1
  end
    
  # this will be run after the method executes
  after do
    # ...
  end

  collection do
    # /api/user/foo
    def foo
      @num + foo # 1 + 3 = 4
    end
  end

  member do
    # If defined in `member` of `collection`
    # it will be called ONLY in respected groups.
    before do
      @num += 2
    end

    # execute after member methods
    after do
      # ...
    end

    # /api/user/:id/foo
    def foo
      @num + foo # (1 + 2) + 3 = 6
    end
  end

  # this will not be in collision with member or collection methods
  def foo
    3
  end
end
```

### Method params

* you can define params directly on the params metod or you can pass as a block
* every param can have `required: true` of default `false` (shorcut `req:`)

```ruby
# inline
params.full_name                         # default String, required: false
params.full_name String, required: false # same

# as a block
params do
  user_email! :email                 # type: :email, required: true
  user_email :email, req: true       # type: :email, required: true
  user_email :email, required: true  # type: :email, required: true
end
```

* every param can have `default:` value that will be applies if value is `blank?`
* min and max are available for Integer, Float

```ruby
params do
  price Integer, min: 20, max: 100000, default: 1000
end
```

* boolean types can be defined in 3 ways

```ruby
activated :boolean # { type: :boolean, default: false }
activated false    # { type: :boolean, default: false }
activated true     # { type: :boolean, default: true }
```

* many supported types and you can define your own types
  * native - `:integer`, `:float`, `:date`, `:datetime`, `:boolean`, `:hash`
  * custom - `:email`, `:url`, `:oib`, `:point` (geo point)

To Define your custom type

## Method methods

### error

If you want to manualy trigger errors

```ruby
def foo
  # trigger named erorr
  error :foo
  
  # default response status is 400
  error 'foo'      # { success: false, code: 400, error: { messages: ['foo'] }}
  
  # you can define response status
  error 404, 'foo' # { success: false, code: 404, error: { messages: ['foo'] }}
end

```

### response

Response object is responsible for response render

```ruby
  # respond with csv data
  # /api/user/1/send_csv
  def send_csv
    response :csv do
      @user.generate_csv_data
    end
  end
  # Content-type: application/csv
  # name, email, ...

  # response with CSV in response data block
  # /api/user/1/send_csv
  def send_csv
    # add "foo" meta response key with value
    response[:foo] = :bar
    # the same
    response.meta :foo, :bar

    # access rack response header
    response.header['content-type'] = 'application/foo'

    # force response.status 404
    response.error 404, 'Object not found'
    # defaults to status: 400
    response.error 'Object not found' 

    # check if response has errors
    response.error?

    # manual set response data
    response.data = :foo
    
    @user.generate_csv_data
  end
  # Content-type: application/json
  # {
  #   success: true,
  #   data: 'csv data...'
  #   message: 'Object updated'
  #   meta: {
  #     foo: :bar 
  #   }
  # }
```

### message

```ruby    
    # add response message
    message 'Object updated'
```

### @api

CleanAPI is not polluting namespace with various instance varaibles. Only `@api` is used.

Basicly, this are options passed to `initialize` or `auto_mount` + instance specifics.

```ruby
def foo
  @api.action == :foo # true
end
```

* `@api.action`        - original triggered action
* `@api.bearer`        - Bearer that is passed in or from a `Auth` [header](https://stackoverflow.com/questions/22229996/basic-http-and-bearer-token-authentication)
* `@api.development`   - `true` or `false`. In development mode
* `@api.id`            - in `member` methods, this will be resource ID.
* `@api.opts`          - Options passed to initializer
* `@api.params`        - Method params hash
* `@api.rack_response` - original rack response object
* `@api.request`       - original rack request object
* `@api.response`      - internal response object, accessible from `response` method
* `@api.uid`           - if using JSON RPC and id is passed, it will be stored here
```
