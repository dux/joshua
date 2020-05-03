<img src="https://i.imgur.com/HWoUz5k.png" align="right" />

# Joshua <small>&mdash; Fast Ruby API</small>

Joshua is opinionated [API](https://learn.g2.com/api) implementation for [Ruby](https://www.ruby-lang.org/en/) based clients, featuring automount for [rack](https://github.com/rack/rack) based clients.

### Features

* Can work in REST or JSON RPC mode.
* Automatic routing + can be mounted as a Rack app, without framework, for unmatched speed and low memory usage
* Automatic documentation builder & Postman import link
* Nearly nothing to learn, pure Ruby clases
* Consistent and predictable request and response flow
* Errors and messages are [localized](./params/type_errors.rb)

<br />

### Components

* Request
  * [REST / JSON RPC](#rest)
  * [auto mount](#auto_mount)
  * [manual mount](#manual_mount)
  * [automatic routing](#routing)
* Base
  * [rescue from](#rescue_from)
  * [before and after](#before)
  * [models](#models)
  * [extending](#extending)
* Method
  * [collections or members](#before)
  * [helper methods](#helper_methods)
  * [description and detail](#desc_and_detail)
  * [annotations + custom annotations](#annotations)
  * [params + custom params](#params)
* [Response](#response)
  * [errors + custom errors](#errors)
  * success
    * meta info
    * [message](#message)
* [Doc builder](#doc_builder)


### Look and feel

Notice how member and collections exist in separate namespace.

```ruby
class ModelApi < Joshua
  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  before do
    @current_user = User.find_by token: @api.bearer
  end

  member do
    def update
    end
  end

  after do
    response[:ip] = @api.request.ip
  end
end

class UsersApi < ModelApi
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

  member do
    def update
    end

    def delete
    end
  end

  def helper_method
  end
end
```

### Annotated example

Featuring **nearly all** you have to know to start building your APIs using Joshua.

```ruby
# in ApplicationApi we will define rules that will reflect all other API classes
class ApplicationAPI < Joshua
  # inside ot the methods you can say `error :foo` and text error will raise
  rescue_from :foo, 'Baz is angry'

  # capture Policy::Error and add custom formating
  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  # define method annotation that will be run before the method executes
  annotation :anonymous do
    @anonymous_allowed = true
  end

  # define custom paramter called label
  # that will allow only characters, with max length of 15
  params :label do |value, opts|
    error 'Label is not in the right format' unless value =~ /^\w{1,15}$/
  end

  # before block wil be executed before any method call
  before do
    # if token provided load user, raise error otherwise
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

  # after block will be run after api method executes
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


# we will create generic ModelAPI, that all models will inherit from
class ModelAPI < ApplicationAPI
  # eexecute before all methods that inherit from ModelAPI
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

  # execute after method exection, only in member methods
  after do
    # add object path to response
    response[:path] = @model.path
  end
end


# example API class for User model
class UsersApi < ModelAPI
  # document this class in various documentations
  documented

  # define methods for methods that do not need id
  collection do
    # describe the method
    desc 'Signup via email to app'
    # define email param, with type of email
    params.email! :email
    # define "/api/users/signup" method
    def signup
      # deliver magic login link
      Mailer.email_login_magic_link(params.email).deliver
      
      # add response message
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
    unsafe
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

      # unless user is admin
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
UserApi.render :login, params: { user: 'foo', pass: 'bar' }
# {
#   success: true,
#   message: 'login ok',
#   meta: { ip: '127.0.0.1' }
# }

UserApi.render :login, params: { user: 'aaa', pass: 'bbb' }
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

<a name="rest"></a>
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

Response is consistent because it is generated from [Joshua::Response](https://github.com/dux/joshua/blob/master/lib/joshua/response.rb) class 
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

<a name="routing"></a>
### Automatic routing

Requests are directly maped to ruby methods

Routes can have max 3 elements.

* **2 elements, "collection" routes without rosource indentifier**
  <br>
  class / collection method
* ***3 elements***
  <br>
  class / resource-id / member method

Example will say it all

```ruby
class UsersApi
  collection do
    # /api/users/login
    def login
      'login'
    end
  end

  member do
    # /api/users/:id/update
    def update
      'update'
    end
  end
end

module Parent
  class Child
    member do
      # Note that you separate modules/classes with a dot.
      # /api/parent.child/:id/nested
      def nested
      end
    end
  end
end
```

It is possible to have custom routes as `/api/:company/:class/:id/:method` etc but you have to configure that manualy. This is what you get "out of the box" by `auto_mount`

This is **ALL** you have to know about routing.

<hr />

<a name="doc_builder"></a>
### Automatic documentation builder

Beautiful documentation is automaticly build for you, with ready libraries for all popular languages.

To enable class documenttion add `documented`

```ruby
class UserApi < Joshua
  documented
  # ...
end
```

Assuming that `Joshua` mount point is `/api`

* You will find interactive HTML documentation on `/api`
* RAW JSON is available on `/api/_/raw`
* [Postman](https://www.postman.com/) import URL is available on `/api/_/postman`

##### Example screenshot

![Screenshot](https://i.imgur.com/i3bgVHG.png)

<hr />

### Consistent and predictable request and response flow

Routing is automatic and response is generated by [Joshua::Response](https://github.com/dux/joshua/blob/master/lib/joshua/response.rb) class.

```ruby
# successuful request
{
  success: true,
  id: 'unique-response-id',
  data: 'csv data...'
  message: 'Object updated'
  meta: {
    foo: :bar 
  }
}

# request with errors - form submit example
{
  success: false,
  errors: {
    messages: ['Foo error', 'Bar error'],
    details: {
      foo: 'Foo error',
      bar: 'Bar error'
    }
  }
}
```


<br />

## Class methods

Methods avaiable on class level.

<a name="rescue_from"></a>
### Rescue from

Similar to Rails `rescue_from`. You can call manualy with `error :foo` or `error 404`, capture named errors and format response as you fit.

```ruby
class UsersApi < Joshua
  rescue_from :foo, 'Baz is angry'

  member do
    # in method
    def foo
      error :foo
    end
  end

  # capture Policy::Error and add custom formating
  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  collection do
    # in method
    def foo
      @user.can.admin! # triggers Policy::Error, gets captured
    end
  end
end
```

<a name="annotations"></a>
### Annotations

Annotations enable us to add API method annotations

#### Example: guest access

Case: If we add `let_guests_in!` annotation we enable guests to use the method.

```ruby
# define method annotation that will be run before the method executes
annotation :let_guests_in! do
  @guets_allowed = true
end

before do
  # before filter picks up annotation and can be used in logic
  error 'Guest access not allowed' unless @user || @guets_allowed
end

collection do
  let_guests_in! # annotation used
  def login
    error 'This will never trigger' unless @user || @guets_allowed
    # ...
  end
end
```

#### Example: working hcaptcha.com / recaptha

Case: If we add `hcaptcha` annotation we enusre that `https://hcaptcha.com` check is passed

```ruby
annotation :hcaptcha! do
  captcha = params['h-captcha-response'] || error('Captcha not selected')
  data    = JSON.parse `curl -d "response=#{captcha}&secret=#{Lux.secrets.hcaptcha.secret}" -X POST https://hcaptcha.com/siteverify`

  unless data['success']
    error 'HCaptcha error: %s' % data['error-codes'].join(', ') 
  end
end

collection do
  desc 'Lost password email (hcaptcha required)'
  hcaptcha!
  params do
    email :email
  end
  def lost_password
    Mailer.lost_pass params.email
    'Mail sent'
  end
end

```

<a name="#params"></a>
### Params

* you can define params directly on the params metod or you can pass as a block
* every param can have `optional: true` or end name with `?`

  ```ruby
  # inline
  params :full_name, min: 2, max: 40

  # inline optional
  params.full_name?                        # default String, required: false
  params.full_name String, required: false # same
  params.full_name String, optional: true # same

  # as a block
  params do
    user_email? :email                 # type: :email, required: false
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
  params do
    is_active :boolean # { type: :boolean, default: false }
    is_active false    # { type: :boolean, default: false }
    is_active true     # { type: :boolean, default: true }
  end
  ```

* many supported types and you can define your own types
  * native - `:integer`, `:float`, `:date`, `:datetime`, `:boolean`, `:hash`
  * custom - `:email`, `:url`, `:oib`, `:point` (geo point)
  * you can as well <a href="#params">define your custom type</a>

#### Define custom params type

You can define custom param type

* first argument is param type
* second argument is param options
* you must return value, value coarse is possible (as memonstrated below)

```ruby
# define custom paramter called label
# that will allow only characters, with max length of 15
params :locale do |value, opts|
  # allow 'en' or 'en-gb'
  error 'Length should be 2 or max 5 chars' unless [2, 5].include?(value.
  error 'Local is not in the right format' unless value =~ /^[\w\-]+$/
  value.downcase
end

member do
  params do
    projet_locale :locale
  end
  def project
    # ...
  end
end
```

<a name="before"></a>
### Before and after & members and collections

* `before` and `after` filters
  * if defined in root,  fill be triggerd on every API method call.
  * if nested under `member` and `collection` will be run only in `member` and `collection` api methods.
* `collection` api methods
  * can be written as `collection do ...` or `collections do ...`
  * will run methods when resource ID is NOT provided
    * example route `/api/users/login`
* `member` api methods
  * can be written as `member do ...` or `members do ...`
  * will run methods when resource ID is provided
    * example route `/api/users/123/show` or `/api/users/abc-def/show`
    * accessible via `@api.id (type: String)`

Example

```ruby
class TestApi < Joshua
  # before block wil be executed before any method call
  before do
    @num = 1
  end
    
  # after will be run after the method executes
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
    # if defined in `member` of `collection`
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
  # any method that is not inside member or collection is a member method
  def foo
    3
  end
end
```

#### Unsafe

Methods marked as unsafe will set option `@api.opts.unsafe == true` 

You can use that information not to check for bearer auth token.

## API methods - inline methods

Joshua specific methods you can call inside API methods (ones in `member` or `collection` blocks)

### error

If you want to manualy trigger errors

```ruby
rescue_from :foo do |error|
  error 403, 'Policy error'
end

def foo
  # trigger named erorr
  error :foo       # { success: false, code: 403, error: { messages: ['Policy error'] }}
  
  # default response status is 400
  error 'foo bar'      # { success: false, code: 400, error: { messages: ['foo bar'] }}
  
  # you can define response status
  error 404, 'foo' # { success: false, code: 404, error: { messages: ['foo'] }}
end

```
<a name="response"></a>
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

<a name="message"></a>
### message

Message method sends message to response.

```ruby    
def update
  # add response message
  message 'Object updated'
  :foo
end
# {
#   success: true,
#   message: 'Object updated'
#   data: 'foo'
# }
```

<a name="helper_methods"></a>
### helper methods

Helper methods are all instance methods defined outside `member` or `collection` scopes


### @api - instance variable

Joshua is not polluting scope with various instance varaibles. Only `@api` variable is used.

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

<a name="extending"></a>
## Extending, mounting, including

There is no `mount`, you just include ruby files like you would to with any other ruby class.

There are 2 ways to create modules ready for inlude

### Plain ruby

Define a module and include it as you would do with any other ruby class.

```ruby
module ApiModuleClasic
  def self.included base
    base.collection do
      def foo
        message 'bar'
      end
    end
  end
end

class UserApi < Joshua
  include ApiModuleClasic
end

# /api/user/foo # { message: 'bar' }
```

### As a plugin

Plugin inteface has few lines less.

```ruby
Joshua.plugin :foo_bar do
  collection do
    def foo
      message 'baz'
    end
  end
end

class UserApi < Joshua
  plugin :foo_bar
end

# /api/user/foo # { message: 'baz' }
```

## Initializing

There are a three basic ways you can initialize yor app

### 1.using config.ru - withouth framework

This is the fasted way with best memory usage.

If you clone this repo and run `puma -p 4000` in root, you can see how local example works.


```ruby
require_relative 'joshua'

class ApplicationApi < Joshua
end

class UsersApi < ApplicationApi
  collection do
    def login
      'To do'
    end
  end
end

run ApplicationApi
# /users/login -> { success: true, data: 'To do' }
```

<a name="auto_mount"></a>
### 2. auto mounting

#### Using [Sinantra](http://sinatrarb.com/)

```ruby
# this will mount api in /api endpoint
post '/api*' do
  ApplicationApi.auto_mount mount_on: '/api',
    request: request,
    response: response,
    development: ENV['RACK_ENV'] == 'development'
end
```

#### Using [Ruby On Rals](https://rubyonrails.org/)

```ruby
# config/routes.rb
match '/api/**', to: 'api#mount', via: [:get, :post]

# app/controllers/api_controller.rb
class ApiController < ApplicationController
  def mount
    ApplicationApi.auto_mount mount_on: '/api',
      request: request,
      response: response,
      development: Rails.env.development?
  end
end
```

<a name="manual_mount"></a>
### 3. Manual mount

When manualy mounting APIs, you need to use specific Joshua endpoint and return the resposnse.

```ruby
post '/api/users/index' do
  result = UsersApi.render :index
  my_format_api_response result
end
```

## Testing & non api usage

No testing helpers provided (for now)

Use this for easy access (get response `Hash`)

```ruby
# call user collection method login
UserApi.render.login(user: 'foo', pass: 'bar')

# call user member method show
UserApi.render.show(123)

# call user member method foo
UserApi.render.foo(123, bar: 'baz')

# or wih user token expanded
UserApi.render :foo, id: 123, bearer: @user.token, params: { bar: 'baz' }
```

## Demos

* Simple demo, runnable rack app https://github.com/dux/joshua/tree/master/demos/simple
* Real life AppicationApi, BaseModelApi, UserApiSimple demo https://github.com/dux/joshua/tree/master/demos/inherited-model

## Dependencies

* **rack** - basic request, response lib
* **json** - better JSON export
* **http** - for JoshuaClient
* **dry-inflector** - `classify`, `constantize`, ...
* **html-tag** - for documention builder
* **clean-hash** - for params in api methods

## Development

After checking out the repo, run bundle install to install dependencies. Then, run rspec to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dux/joshua. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the Contributor Covenant code of conduct.

## License

The gem is available as open source under the terms of the MIT License.