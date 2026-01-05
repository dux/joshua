<img src="https://i.imgur.com/HWoUz5k.png" align="right" />

# Joshua <small>&mdash; Fast Ruby API</small>

Joshua is opinionated [API](https://learn.g2.com/api) implementation for [Ruby](https://www.ruby-lang.org/en/) based clients, featuring automount for [rack](https://github.com/rack/rack) based clients.

### Features

* Can work in REST or JSON RPC mode
* Automatic routing + can be mounted as a Rack app, without framework, for unmatched speed and low memory usage
* Automatic documentation builder & [Postman](https://www.postman.com/) / [Insomnia](https://insomnia.rest/) import link
* Nearly nothing to learn, pure Ruby classes
* Consistent and predictable request and response flow
* Errors and messages are localized

<br />

### Installation

#### Requirements

* Ruby 2.5 or higher (tested with Ruby 2.7, 3.0, 3.1, 3.2)
* Bundler (for dependency management)

#### Install via RubyGems

```bash
gem install joshua
```

#### Add to Gemfile

```ruby
# From RubyGems
gem 'joshua'

# From GitHub (latest development version)
gem 'joshua', git: 'git@github.com:dux/joshua.git'
```

#### Basic usage

```ruby
require 'joshua'
```

### Components

* Request Flow
  * [REST / JSON RPC](#rest)
  * [auto mount](#auto_mount)
  * [manual mount](#manual_mount)
  * [automatic routing](#routing)
* API Methods
  * [collections or members](#before-and-after-filters)
  * [helper methods](#helper-methods)
  * [annotations + custom annotations](#annotations)
  * [params + custom params](#params)
    * [models](#models)
* [Response](#response)
  * [errors + custom errors](#errors)
  * success
    * meta info
    * [message](#message)
* Class methods
  * [rescue from](#rescue-from)
  * [before and after](#before-and-after-filters)
  * [extending and including](#extending-and-including)
* [Doc builder](#automatic-documentation-builder)


### Speed

Joshua **directly** maps requests to method calls, without routing and it also can work mounted directly on the rack interface, as demonstrated [here](https://github.com/dux/joshua/blob/master/demos/simple/config.ru).

By using plain ruby classes, direct mapping without routing and providing direct `rack` access if needed, it is hard to beat Joshua in pure speed.

### Look and feel

* `member (/foo/123/bar)` and `collection (/foo/bar)` exist in separate namespace. You can have `member` and `collection` `update` methods if you need to.
* `rescue_from`, `before` and `after` filters are supported.
* You can inherit methods from parent class just as in plain ruby. Define generic `show`, `create`, `update` and `delete` methods and inherit them in parent classes.
* Many more features

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
    # you can define methods as ruby methods
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

    # or wrap them in define block for better visual semantics
    define :login do
      desc   'Login test'
      detail 'user + pass = foo + bar'
      params do
        user
        pass
      end
      proc do # or lambda or anything that responds to call
        if params.user == 'foo' && params.pass == 'bar'
          message 'Login ok'

          'token-abcdefg'
        else
          error 'Bad user name or pass'
        end
      end
    end
  end

  member do
    def update
    end

    define :delete do
      lambda {}
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
  # inside of methods you can say `error :foo` and text error will raise
  rescue_from :foo, 'Baz is angry'

  # capture Policy::Error and add custom formatting
  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  # define method annotation that will be run before method executes
  annotation :anonymous do
    @anonymous_allowed = true
  end

  # define custom parameter called label
  # that will allow only characters, with max length of 15
  params :label do |value, opts|
    error 'Label is not in the right format' unless value =~ /^\w{1,15}$/
  end

  # before block will be executed before any method call
  before do
    # if token provided load user, raise error otherwise
    if @api.bearer
      @current_user = User.find_by token: @api.bearer

      # raise unless user found
      error 'Invalid API token' unless @current_user
    end

    # raise error unless @user defined and we do not allow anonymous access
    if !@current_user && !@anonymous_allowed
      error 'Anonymous access not allowed, please register'
    end

    # we will use this time to calculate method execution speed
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
  # execute before all methods that inherit from ModelAPI
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

  # execute after method execution, only in member methods
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
    # define email param, with type of email, required
    params do
      email :email
    end
    # define "/api/users/signup" method
    def signup
      # deliver magic login link
      Mailer.email_login_magic_link(params.email).deliver

      # add response message
      message 'Email with login link sent to %s' % params.email
    end

    # params can be defined as a block as well
    params do
      # method name in a block is parameter name, and it is required
      # String is default type, you can skip writing it
      user String
      # if you add question mark, it is not required
      pass? :string
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

    # /api/users/:id/delete
    def delete
      @user.destroy
      message 'You deleted yourself'
    end

    # you can use define to create an api method, to have all nested under readable block
    # just be sure that you return a proc or lambda as a last argument
    # /api/users/:id/re_tokenize
    define :re_tokenize do
      desc 'Generate new user access token'
      proc do
        @user.update token: Crypt.random(40)
        message 'New token generated'
      end
    end
  end
end


# Example api call with response
UserApi.render :login, params: { user: 'foo', pass: 'bar' }
UserApi.render.login(user: 'foo', pass: 'bar')
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

By default API works on POST for all methods and raises error for any other request type. You can modify the behavior by enabling specific methods using for example `allow :get` to allow `HTTP GET`.

#### Example requests

```bash
# this POST request will work in production by default
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
    response do
      @user.generate_csv_data
    end
  end
  # Content-type: text/plain
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

Requests are directly mapped to ruby methods

Routes can have max 3 elements.

* **2 elements, "collection" routes without resource identifier**
  <br>
  class / collection method
* **3 elements**
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

It is possible to have custom routes as `/api/:company/:class/:id/:method` etc but you have to configure that manually. This is what you get "out of the box" by `auto_mount`

This is **ALL** you have to know about routing.

<hr />

<a name="automatic-documentation-builder"></a>
### Automatic documentation builder

Beautiful documentation is automatically built for you, with ready libraries for all popular languages.

To enable class documentation add `documented`

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
# successful request
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

Methods available on class level.

<a name="rescue-from"></a>
### Rescue from

Similar to Rails `rescue_from`. You can call manually with `error :foo` or `error 404`, capture named errors and format response as you fit.

```ruby
class UsersApi < Joshua
  rescue_from :foo, 'Baz is angry'

  member do
    # in method
    def foo
      error :foo
    end
  end

  # capture Policy::Error and add custom formatting
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
  @guests_allowed = true
end

before do
  # before filter picks up annotation and can be used in logic
  error 'Guest access not allowed' unless @current_user || @guests_allowed
end

collection do
  let_guests_in! # annotation used
  def login
    error 'This will never trigger' unless @current_user || @guests_allowed
    # ...
  end
end
```

#### Example: working hcaptcha.com / recaptcha

Case: If we add `hcaptcha` annotation we ensure that `https://hcaptcha.com` check is passed

```ruby
annotation :hcaptcha! do
  captcha = params['h-captcha-response'] || error('Captcha not selected')
  data    = JSON.parse `curl -d "response=#{captcha}&secret=#{ENV['HCAPTCHA_SECRET']}" -X POST https://hcaptcha.com/siteverify`

  unless data['success']
    error 'HCaptcha error: %s' % data['error-codes'].join(', ')
  end
end

collection do
  define :lost_password do
    desc 'Lost password email (hcaptcha required)'
    hcaptcha!
    params do
      email :email
    end
    proc do
      Mailer.lost_pass params.email
      'Mail sent'
    end
  end
end

```

<a name="params"></a>
### Params

* You can define params directly on the params method or you can pass as a block
* Every param can have `optional: true` or end name with `?`

  ```ruby
  # inline
  params :full_name, min: 2, max: 40

  # inline optional
  params.full_name?                        # default String, required: false
  params.full_name String, required: false # same
  params.full_name String, optional: true # same

  # as a block
  params do
    user_email? :email                  # type: :email, required: false
    user_email  :email, required: true       # type: :email, required: true
    user_email  :email, req: true       # type: :email, required: true
  end
  ```

* Every param can have `default:` value that will be applied if value is `blank?`
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

* array types are supported

  ```ruby
  params do
    labels Array[:label] # Collection
    labels Set[:label]   # In Set duplicates are discarded

    # if data is provided in a string and not in a Array value
    # you can define a delimiter that will split String to Array
    labels Array[:label], delimiter: /\s*,\s*/
  end
  ```

* Many supported types and you can define your own types
  * native - `:integer`, `:float`, `:date`, `:datetime`, `:boolean`, `:hash`
  * custom - `:email`, `:url`, `:oib`, `:point` (geo point)
  * you can as well define your custom type

#### Define custom params type

You can define custom param type

* first argument is param type
* second argument is param options
* you must return value, value coercion is possible (as demonstrated below)

```ruby
# define custom parameter called label
# that will allow only characters, with max length of 15
params :locale do |value, opts|
  # allow 'en' or 'en-gb'
  error 'Length should be 2 or max 5 chars' unless [2, 5].include?(value.length)
  error 'Local is not in the right format' unless value =~ /^[\w\-]+$/
  value.downcase
end

member do
  params do
    project_locale :locale
  end
  def project
    # ...
  end
end
```

<a name="before-and-after-filters"></a>
### Before and after & members and collections

* `before` and `after` filters
  * If defined in root, will be triggered on every API method call.
  * If nested under `member` and `collection` will be run only in `member` and `collection` api methods.
* `collection` api methods
  * Can be written as `collection do ...` or `collections do ...`
  * Will run methods when resource ID is NOT provided
    * example route `/api/users/login`
* `member` api methods
  * Can be written as `member do ...` or `members do ...`
  * Will run methods when resource ID is provided
    * example route `/api/users/123/show` or `/api/users/abc-def/show`
    * accessible via `@api.id (type: String)`

Example

```ruby
class TestApi < Joshua
  # before block will be executed before any method call
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
      @num + 3 # 1 + 3 = 4
    end
  end

  member do
    # if defined in `member` or `collection`
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
      @num + 3 # (1 + 2) + 3 = 6
    end
  end

  # this will not be in collision with member or collection methods
  # any method that is not inside member or collection is a member method
  def foo
    3
  end
end
```

### after_auto_mount

If you want to modify api request after mount. First parameter is class+method path and second is all options hash.

```ruby
# /api/cisco/contracts/list
# convert to
# /api/contracts/list?org_id=123

after_auto_mount do |nav, opts|
  if org = Org.find_by code: nav.first
    nav.shift
    opts[:params][:org_id] = org.id
  end
end
```

### unsafe

Methods marked as unsafe will set option `@api.opts.unsafe == true`

You can use that information not to check for bearer auth token in `before` filter.

<a name="models"></a>
### Models

API models can be defined and parameters can be checked against the models

```ruby
class ApplicationApi
  model :company do
    id      Integer
    name    String
    address :address
  end

  model User do
    id       Integer
    name     String
    email    :email
    is_admin :boolean

    # If proc is defined and returned, filtering will be applied
    #   before the data is forwarded to api method
    # In this case raise error if :is_admin attribute is defined but user
    #   is not allowed to change it
    proc do |data|
      if !data[:is_admin].nil? && !user.can.admin?
        error 'You are not allowed change the value of :is_admin attribute'
      end
    end
  end
end

class UserApi
  members do
    desc 'Update user options'
    params do
      user model: User
    end
    def update
      # ...
    end
  end
end
```

## API methods - inline methods

Joshua specific methods you can call inside API methods (ones in `member` or `collection` blocks)

### error

If you want to manually trigger errors

```ruby
rescue_from :foo do |error|
  error 403, 'Policy error'
end

def foo
  # trigger named error
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
    response do
      @user.generate_csv_data
    end
  end
  # Content-type: text/plain
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
    error 404, 'Object not found'
    # defaults to status: 400
    error 'Object not found'

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

<a name="helper-methods"></a>
### helper methods

Helper methods are all instance methods defined outside `member` or `collection` scopes

<a name="errors"></a>
### response errors

You are free to use all HTTP error status codes, but we suggest to use only `400` for handled errors and `500` for unhandled errors, and of course, try to provide nice error descriptions.

#### Example

```ruby
rescue_from :big_load do
  custom_logger :load_too_big
  error 'There is too big load on the API, please try again or sign up for priority access'
end

def foo
  # response.status: 400
  error 'Object not found'

  # response.status 400, error.code: 404
  error 'Object not found', code: 404

  # response.status 404, error.code: 404
  error 'Object not found', status: 404, code: 404

  # unhandled, response.status: 500
  raise 'Some error'

  # execute rescued :big_load
  error :big_load
end
```

### @api - instance variable

Joshua is not polluting scope with various instance variables. Only `@api` variable is used.

Basically, these are options passed to `initialize` or `auto_mount` + instance specifics.

```ruby
def foo
  @api.action == :foo # true
end
```

* `@api.action`        - original triggered action
* `@api.bearer`        - Bearer that is passed in or from an `Auth` [header](https://stackoverflow.com/questions/22229996/basic-http-and-bearer-token-authentication)
* `@api.development`   - `true` or `false`. In development mode
* `@api.id`            - in `member` methods, this will be resource ID.
* `@api.opts`          - Options passed to initializer
* `@api.params`        - Method params hash
* `@api.rack_response` - original rack response object
* `@api.request`       - original rack request object
* `@api.response`      - internal response object, accessible from `response` method
* `@api.uid`           - if using JSON RPC and id is passed, it will be stored here

<a name="extending-and-including"></a>
## Extending, mounting, including

There is no `mount`, you just include ruby files like you would with any other ruby class.

There are 2 ways to create modules ready for include

### Plain ruby

Define a module and include it as you would do with any other ruby class.

```ruby
module ApiModuleClassic
  def self.included base
    base.collection do
      def foo
        message 'bar'
      end
    end
  end
end

class UserApi < Joshua
  include ApiModuleClassic
end

# /api/user/foo # { message: 'bar' }
```

### Calling super methods

If you want to call `super` to call super method inside api methods, you need to call them with `super!`. You can also pass a super method name as an argument.

```ruby
class ParentApi < Joshua
  collection do
    def foo
      123
    end
  end
end

class ChildApi < ParentApi
  collection do
    def foo
      super! # 123
      345
    end

    def bar
      foo         # 345
      super! :foo # 123
    end
  end
end
```

### As a plugin

Plugin interface has few lines less.

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

There are three basic ways you can initialize your app

### 1. Using config.ru - without framework

This is fastest way with best memory usage.

If you clone this repo and run `puma -p 4000` in root, you can see how local example works.


```ruby
require 'joshua'

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
### 2. Auto mounting

#### Using [Sinatra](http://sinatrarb.com/)

```ruby
# this will mount api in /api endpoint
post '/api*' do
  ApplicationApi.auto_mount mount_on: '/api',
    request: request,
    response: response,
    development: ENV['RACK_ENV'] == 'development'
end
```

#### Using [Ruby On Rails](https://rubyonrails.org/)

```ruby
# config/routes.rb
mount ApplicationApi => '/api'
# or
match '/api/**', to: 'api#mount', via: [:get, :post]

# app/controllers/api_controller.rb
class ApiController < ApplicationController
  def mount
    ApplicationApi.auto_mount mount_on: '/api',
      api_host: self,
      bearer: user.try(:token),
      development: Rails.env.development?
  end
end
```

<a name="manual_mount"></a>
### 3. Manual mount

When manually mounting APIs, you need to use specific Joshua endpoint and return the response.

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

# or with user token expanded
UserApi.render :foo, id: 123, bearer: @user.token, params: { bar: 'baz' }
```

## Demos

* Simple demo, runnable rack app https://github.com/dux/joshua/tree/master/demos/simple
* Real life ApplicationApi, BaseModelApi, UserApiSimple demo https://github.com/dux/joshua/tree/master/demos/inherited-model

## Dependencies

* **rack** - basic request, response lib
* **json** - better JSON export
* **http** - for JoshuaClient
* **dry-inflector** - `classify`, `constantize`, ...
* **html-tag** - for documentation builder
* **hash_wia** - for params in api methods

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dux/joshua. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the Contributor Covenant code of conduct.

## Advanced Topics

### Authentication and Authorization Patterns

Joshua provides flexible authentication through `@api.bearer` token and before filters:

#### JWT Token Authentication

```ruby
class ApplicationApi < Joshua
  before do
    if @api.bearer
      begin
        payload = JWT.decode(@api.bearer, Rails.application.secret_key_base)[0]
        @current_user = User.find(payload['user_id'])
      rescue JWT::DecodeError => e
        error 401, 'Invalid token: %s' % e.message
      end
    end
  end
end
```

#### API Key Authentication

```ruby
class ApplicationApi < Joshua
  before do
    api_key = @api.request.env['HTTP_X_API_KEY']
    @api_client = ApiClient.find_by(key: api_key)
    error 401, 'Invalid API key' unless @api_client
  end
end
```

#### Role-Based Access Control

```ruby
class AdminApi < ApplicationApi
  before do
    error 403, 'Admin access required' unless @current_user&.admin?
  end

  collection do
    def users
      User.all.map(&:api_export)
    end
  end
end
```

### Error Handling Best Practices

#### Custom Error Classes

```ruby
class ApplicationApi < Joshua
  class ValidationError < StandardError; end
  class NotFoundError < StandardError; end
  class RateLimitError < StandardError; end

  rescue_from ValidationError do |e|
    error 422, 'Validation failed: %s' % e.message
  end

  rescue_from NotFoundError do |e|
    error 404, e.message
  end

  rescue_from RateLimitError do |e|
    response.header['X-RateLimit-Reset'] = e.reset_at.to_i.to_s
    error 429, 'Rate limit exceeded. Try again in %d seconds' % e.retry_after
  end
end
```

#### Structured Error Responses

```ruby
class UsersApi < ApplicationApi
  collection do
    params do
      email :email
      password String, min: 8
      age Integer, min: 18, max: 120
    end
    def signup
      user = User.new(params.to_h)

      if user.save
        user.token
      else
        # Returns detailed field errors
        error 422, 'Validation failed', details: user.errors.to_hash
      end
    end
  end
end
```

### Database Integration Examples

#### ActiveRecord Integration

```ruby
class ModelApi < ApplicationApi
  before do
    @model_class = self.class.to_s.sub(/Api$/, '').constantize
    @model = @api.id ? @model_class.find(@api.id) : @model_class.new
  rescue ActiveRecord::RecordNotFound
    error 404, '%s not found' % @model_class.name
  end

  member do
    def update
      if @model.update(params.to_h)
        message 'Updated successfully'
        @model.api_export
      else
        error 422, 'Update failed', details: @model.errors
      end
    end
  end
end
```

#### Sequel Integration

```ruby
class SequelModelApi < ApplicationApi
  before do
    @model = DB[:users].where(id: @api.id).first
    error 404, 'User not found' unless @model
  end

  member do
    def show
      @model
    end
  end
end
```

### API Versioning Strategies

#### Header-Based Versioning

```ruby
class ApplicationApi < Joshua
  before do
    @api_version = @api.request.env['HTTP_API_VERSION'] || 'v1'
  end
end

module V1
  class UsersApi < ApplicationApi
    # V1 implementation
  end
end

module V2
  class UsersApi < ApplicationApi
    # V2 implementation with breaking changes
  end
end
```

#### Path-Based Versioning

```ruby
# In your rack app
map '/api/v1' do
  run V1::ApplicationApi
end

map '/api/v2' do
  run V2::ApplicationApi
end
```

### File Upload Handling

```ruby
class FilesApi < ApplicationApi
  collection do
    desc 'Upload a file'
    params do
      file Hash # Rack::Multipart::UploadedFile
      description? String
    end
    def upload
      uploaded_file = params.file

      # Validate file
      error 'No file provided' unless uploaded_file
      error 'File too large' if uploaded_file[:tempfile].size > 10.megabytes

      # Save file
      filename = SecureRandom.hex + File.extname(uploaded_file[:filename])
      path = Rails.root.join('uploads', filename)

      File.open(path, 'wb') do |f|
        f.write(uploaded_file[:tempfile].read)
      end

      { url: "/uploads/#{filename}", size: uploaded_file[:tempfile].size }
    end
  end
end
```

### CORS Configuration

```ruby
class ApplicationApi < Joshua
  after do
    # Allow CORS for all origins (customize as needed)
    response.header['Access-Control-Allow-Origin'] = '*'
    response.header['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    response.header['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end

  # Handle preflight requests
  collection do
    allow :options
    def options
      response.status = 204
      nil
    end
  end
end
```

### Rate Limiting

```ruby
class ApplicationApi < Joshua
  before do
    # Simple Redis-based rate limiting
    if @current_user
      key = "rate_limit:#{@current_user.id}:#{Time.now.to_i / 60}"
      count = Redis.current.incr(key)
      Redis.current.expire(key, 60) if count == 1

      if count > 100 # 100 requests per minute
        error 429, 'Rate limit exceeded. Please try again later.'
      end
    end
  end
end
```

## Testing Your APIs

### RSpec Testing

```ruby
# spec/api/users_api_spec.rb
require 'spec_helper'

RSpec.describe UsersApi do
  let(:user) { User.create!(email: 'test@example.com', token: 'test-token') }

  describe 'POST /users/login' do
    it 'returns token for valid credentials' do
      result = UsersApi.render.login(user: 'foo', pass: 'bar')

      expect(result[:success]).to be true
      expect(result[:data]).to match(/^token-/)
    end

    it 'returns error for invalid credentials' do
      result = UsersApi.render.login(user: 'wrong', pass: 'wrong')

      expect(result[:success]).to be false
      expect(result[:error][:messages]).to include('Wrong user or pass')
    end
  end

  describe 'GET /users/:id/show' do
    it 'returns user data when authorized' do
      result = UsersApi.render.show(user.id, bearer: user.token)

      expect(result[:success]).to be true
      expect(result[:data][:email]).to eq(user.email)
    end

    it 'returns error when unauthorized' do
      result = UsersApi.render.show(user.id, bearer: 'invalid-token')

      expect(result[:success]).to be false
      expect(result[:error][:code]).to eq(401)
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/api_spec.rb
require 'rack/test'

describe 'API Integration' do
  include Rack::Test::Methods

  def app
    ApplicationApi
  end

  it 'handles JSON requests' do
    post '/api/users/login',
         { user: 'foo', pass: 'bar' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    expect(json['success']).to be true
  end
end
```

## Deployment and Production

### Performance Optimization

```ruby
# config.ru for production
require 'bundler/setup'
require_relative 'app'

# Enable response compression
use Rack::Deflater

# Add request ID for tracking
use Rack::RequestId

# Add timeout handling
use Rack::Timeout, service_timeout: 30

# Mount the API
run ApplicationApi
```

### Production Configuration

```ruby
class ApplicationApi < Joshua
  configure :production do
    # Disable detailed error messages
    rescue_from StandardError do |e|
      logger.error "API Error: #{e.message}\n#{e.backtrace.join("\n")}"
      error 500, 'Internal server error'
    end

    # Add security headers
    after do
      response.header['X-Content-Type-Options'] = 'nosniff'
      response.header['X-Frame-Options'] = 'DENY'
      response.header['X-XSS-Protection'] = '1; mode=block'
    end
  end
end
```

### Docker Deployment

```dockerfile
# Dockerfile
FROM ruby:3.2-slim

RUN apt-get update -qq && apt-get install -y build-essential

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Monitoring and Logging

```ruby
class ApplicationApi < Joshua
  before do
    @request_id = SecureRandom.uuid
    logger.info "[#{@request_id}] #{@api.request.request_method} #{@api.request.path}"
    @start_time = Time.now
  end

  after do
    duration = ((Time.now - @start_time) * 1000).round(2)
    status = response.error? ? 'ERROR' : 'SUCCESS'
    logger.info "[#{@request_id}] #{status} in #{duration}ms"
  end
end
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "undefined method 'render' for UserApi:Class"

**Solution:** Make sure you're inheriting from `Joshua` or a class that inherits from it:

```ruby
class UserApi < Joshua  # or < ApplicationApi
  # ...
end
```

#### Issue: "No route matches"

**Solution:** Check that your method is defined within `collection` or `member` blocks:

```ruby
class UserApi < Joshua
  collection do  # for routes without ID
    def login
    end
  end

  member do      # for routes with ID
    def show
    end
  end
end
```

#### Issue: "Bearer token not working"

**Solution:** Ensure you're passing the token correctly:

```ruby
# In HTTP headers
Authorization: Bearer your-token-here

# Or in the render call
UserApi.render.show(123, bearer: 'your-token-here')
```

#### Issue: "Params validation not working"

**Solution:** Ensure params are defined before the method:

```ruby
collection do
  params do      # Must come before the method
    email :email
  end
  def login      # Method definition after params
    # ...
  end
end
```

#### Issue: "Can't see API documentation"

**Solution:** Add `documented` to your API class:

```ruby
class UserApi < Joshua
  documented     # Enable documentation
  # ...
end
```

#### Issue: "JSON RPC mode not working"

**Solution:** Ensure your request format is correct:

```bash
curl -X POST http://localhost:3000/api \
  -H "Content-Type: application/json" \
  -d '{
    "id": "unique-request-id",
    "action": ["users", "123", "show"],
    "params": {"include": "profile"}
  }'
```

## License

The gem is available as open source under the terms of the MIT License.
