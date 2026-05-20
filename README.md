<img src="public/joshua-tree.png" align="right" width="100" />

# Joshua

Fast, opinionated Ruby API framework with automatic routing and documentation.

## Overview

Joshua maps HTTP requests directly to Ruby methods without routing configuration. It works as a standalone Rack app or integrates with Rails/Sinatra.

```ruby
class UsersApi < Joshua
  unsafe
  desc 'Authenticate user'
  params do
    email :email
    pass String
  end
  def login
    user = User.authenticate(params.email, params.pass)
    user ? user.token : error('Invalid credentials')
  end

  ref do
    def show
      User.find(@ref).to_h
    end
  end
end

# Routes created automatically:
# POST /api/users/login
# POST /api/users/:ref/show
```

## Class structure

* Public methods at class root are **collection** endpoints (no resource id).
* Methods inside `ref do ... end` are **ref/member** endpoints (with a resource id) - each is renamed to `<name>_ref` after the block.
* `private` methods are never exposed as endpoints - they remain callable helpers.

```ruby
class UsersApi < Joshua
  def list                    # /users/list
    User.all.map(&:to_h)
  end

  ref do
    def show                  # /users/:ref/show
      User.find(@ref).to_h
    end
  end

  private

  def normalize_email str     # helper, never reachable as endpoint
    str.to_s.strip.downcase
  end
end
```

Two convenience ivars are set before any action runs:

* `@ref`          - the resource id from the URL (`nil` for collection actions)
* `@bearer_token` - `Authorization: Bearer <token>` from the request

The full `@api` accessor is still available (see [Instance Variables](#instance-variables)).

## Installation

```ruby
# Gemfile
gem 'joshua'

# Or from GitHub
gem 'joshua', git: 'https://github.com/dux/joshua.git'
```

Requires Ruby 2.5+.

## Quick Start

### Standalone (config.ru)

```ruby
require 'joshua'

class ApplicationApi < Joshua
end

class UsersApi < ApplicationApi
  def ping
    'pong'
  end
end

run ApplicationApi
```

Run with `rackup -p 3000`, then `curl -X POST http://localhost:3000/users/ping`.

### Rails Integration

```ruby
# config/routes.rb
match '/api/*path', to: 'api#handle', via: [:get, :post]

# app/controllers/api_controller.rb
class ApiController < ApplicationController
  def handle
    ApplicationApi.auto_mount(
      mount_on: '/api',
      api_host: self,
      bearer: current_user&.token,
      development: Rails.env.development?
    )
  end
end
```

### Sinatra Integration

```ruby
post '/api/*' do
  ApplicationApi.auto_mount(
    mount_on: '/api',
    request: request,
    response: response
  )
end
```

## Defining endpoints

Either `def name` (preferred when no DSL siblings are needed) or `define :name do ... proc do ... end end` (preferred when you want the body, params, and metadata visually grouped):

```ruby
# def style
desc 'Login endpoint'
params { email :email }
def login
  User.authenticate(params.email)
end

# define style
define :login do
  desc 'Login endpoint'
  params { email :email }
  proc { User.authenticate(params.email) }
end
```

Both work at class root (collection) or inside `ref do ... end` (ref/member).

## Routing

| URL                       | Where the method lives           |
|---------------------------|----------------------------------|
| `POST /api/users/login`   | root `def login` or `define`     |
| `POST /api/users/123/show`| inside `ref do def show ... end` |

Class name `UsersApi` becomes the route prefix `users`. Namespaced `Admin::UsersApi` becomes `admin.users`.

```ruby
module Admin
  class UsersApi < Joshua
    ref do
      def ban   # /api/admin.users/:ref/ban
      end
    end
  end
end
```

## Parameters

```ruby
params do
  email :email                    # required email
  name String                     # required string
  age? Integer                    # optional integer
  role String, default: 'user'    # with default
  score Integer, min: 0, max: 100
end
def signup
  params.email  # dot notation
  params[:name] # hash syntax
end
```

### Built-in types

* `:string` (default), `:integer`, `:float`, `:boolean`
* `:email`, `:url`, `:date`, `:datetime`, `:hash`
* Typero built-ins: `:label`, `:slug`, `:phone`, `:oib`, `:iban`, `:uuid`, ...

### Array parameters

```ruby
params do
  tags Array[:string]
  tags Array[:string], delimiter: /\s*,\s*/  # split a string input
end
```

## Response format

```ruby
# Success
{
  success: true,
  data: "returned value",
  message: "Optional message",
  meta: { custom: "metadata" }
}

# Error
{
  success: false,
  error: {
    messages: ["Error description"],
    details: { field: "Field error" }
  }
}
```

### Response methods

```ruby
def update
  message 'User updated'           # set response message
  response[:request_id] = @api.uid # add metadata
  response.meta :version, '1.0'    # same as above
  { id: 1, name: 'foo' }           # return value -> data
end
```

### Custom content types

```ruby
define :export_csv do
  proc do
    response { @user.to_csv }  # bypasses JSON wrapper
  end
end
```

## Error handling

```ruby
def foo
  error 'Something went wrong'                       # 400
  error 404, 'Not found'                             # custom status
  error 403, 'Forbidden', code: 'ACCESS_DENIED'      # with code
end
```

### Named errors and rescue_from

```ruby
class ApplicationApi < Joshua
  rescue_from :unauthorized, 'Authentication required'

  rescue_from ActiveRecord::RecordNotFound do |e|
    error 404, 'Record not found'
  end

  rescue_from :all do |e|
    error 500, 'Internal error'
  end
end

class UsersApi < ApplicationApi
  ref do
    def show
      error :unauthorized unless @current_user
      User.find(@ref)
    end
  end
end
```

## Lifecycle callbacks

Root callbacks fire for both collection and ref actions. `ref do before do end end` scopes to member actions only.

```ruby
class ApplicationApi < Joshua
  before do
    @current_user = User.find_by(token: @bearer_token) if @bearer_token
  end

  after do
    response[:timestamp] = Time.now.iso8601
  end
end

class UsersApi < ApplicationApi
  ref do
    before do
      @user = User.find(@ref)   # runs only for member actions
    end

    def show
      @user.to_h
    end
  end
end
```

## Authentication

```ruby
# Request: Authorization: Bearer abc123

class ApplicationApi < Joshua
  before do
    next unless @bearer_token
    @current_user = User.find_by(token: @bearer_token)
    error 401, 'Invalid token' unless @current_user
  end
end
```

### Unsafe methods

Skip the auth requirement on a per-method basis:

```ruby
unsafe
def login
  # @api.method_opts[:unsafe] == true so a parent `before` can opt out
end
```

## Annotations

Reusable method decorators:

```ruby
class ApplicationApi < Joshua
  annotation :require_admin do
    error 403, 'Admin required' unless @current_user&.admin?
  end

  annotation :rate_limit do |limit|
    check_rate_limit(@current_user, limit)
  end
end

class AdminApi < ApplicationApi
  require_admin
  rate_limit 10
  def delete_all
  end
end
```

## Models (reusable param schemas)

```ruby
class ApplicationApi < Joshua
  model :user_input do
    name String
    email :email
    role? String
  end
end

class UsersApi < ApplicationApi
  ref do
    params { user model: :user_input }
    def update
      @user.update(params.user)
    end
  end
end
```

## HTTP methods

By default endpoints accept POST only. Use RESTful syntax to allow others:

```ruby
define get: :show do
  proc { }
end

define put: :update do
  proc { }
end

# Multiple methods for one action - hash rocket required for array key
define [:get, :put] => :settings do
  proc { }
end

# Or allow inside the body
define :archive do
  allow :put
  proc { }
end

allow :get, :put, :delete
def config
end
```

## API documentation

```ruby
class UsersApi < Joshua
  documented
  class_desc   'User operations'
  class_detail 'Long description for the whole class'

  desc 'Login endpoint'
  detail 'Returns JWT token on success'
  params do
    email :email
    pass String
  end
  def login
  end
end
```

Available at:
* `/api`            - interactive HTML docs
* `/api/_/raw`      - JSON schema
* `/api/_/postman`  - Postman import URL

## JSON RPC mode

```bash
curl -X POST http://localhost:3000/api \
  -H "Content-Type: application/json" \
  -d '{
    "id": "req-123",
    "action": ["users", "123", "show"],
    "params": {"include": "profile"}
  }'
```

## Testing

Call API methods directly without HTTP:

```ruby
# Collection method
result = UsersApi.render.login(email: 'foo@bar.com', pass: 'secret')

# Member method
result = UsersApi.render.show(123)

# With bearer token
result = UsersApi.render.show(123, bearer: 'user-token')

# Alternative syntax
result = UsersApi.render(:login, params: { email: 'foo@bar.com' })
```

### RSpec example

```ruby
RSpec.describe UsersApi do
  describe '.login' do
    it 'returns token for valid credentials' do
      result = UsersApi.render.login(email: 'test@example.com', pass: 'valid')
      expect(result[:success]).to be true
    end

    it 'returns error for invalid credentials' do
      result = UsersApi.render.login(email: 'test@example.com', pass: 'wrong')
      expect(result[:success]).to be false
    end
  end
end
```

## Inheritance

API classes inherit normally. Plain `super` works for collection methods. Inside `ref do`, use `super!` (the internal `_ref` rename breaks Ruby's `super`).

```ruby
class ApplicationApi < Joshua
  before { @current_user = authenticate }
  after  { log_request }
end

class ModelApi < ApplicationApi
  before do
    @model = load_model(@ref) if @ref
  end

  ref do
    def show
      @model.to_h
    end

    def delete
      @model.destroy
      message 'Deleted'
    end
  end
end

class UsersApi < ModelApi
  # inherits show, delete, and all callbacks
end

class PostsApi < ModelApi
  ref do
    def show
      base = super!
      base.merge(extra: 'something')
    end
  end
end
```

## Plugins

```ruby
Joshua.plugin :pagination do
  private

  def paginate(collection)
    page = (params.page || 1).to_i
    per  = (params.per  || 20).to_i
    collection.limit(per).offset((page - 1) * per)
  end
end

class UsersApi < Joshua
  plugin :pagination

  def index
    paginate(User.all).map(&:to_h)
  end
end
```

## Instance variables

The most-used convenience ivars (set before any callback or action body):

| Variable        | Description                                            |
|-----------------|--------------------------------------------------------|
| `@ref`          | Resource id from URL (member only; nil for collection) |
| `@bearer_token` | Bearer token from `Authorization` header               |

Full `@api` accessor:

| Variable             | Description                                            |
|----------------------|--------------------------------------------------------|
| `@api.id`            | Resource id (same as `@ref`)                           |
| `@api.bearer`        | Bearer token (same as `@bearer_token`)                 |
| `@api.action`        | Current method name (symbol)                           |
| `@api.params`        | Request parameters                                     |
| `@api.request`       | Rack request object                                    |
| `@api.response`      | Joshua response object                                 |
| `@api.method_opts`   | Per-method options (params, allow, unsafe, ...)        |
| `@api.opts`          | Options passed to the initializer                      |
| `@api.development`   | Development-mode flag                                  |

## Reference example

`spec/api/kitchen_sink_api.rb` + `spec/tests/kitchen_sink_spec.rb` exercise every DSL feature in one place - use them as the single source of truth for the current syntax.

## Dependencies

* rack
* json
* html-tag
* hash_wia
* typero

## Development

```bash
git clone https://github.com/dux/joshua.git
cd joshua
bundle install
bundle exec rspec
```

## License

MIT License
