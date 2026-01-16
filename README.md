<img src="public/joshua-tree.png" align="right" width="100" />

# Joshua

Fast, opinionated Ruby API framework with automatic routing and documentation.

## Overview

Joshua maps HTTP requests directly to Ruby methods without routing configuration. It works as a standalone Rack app or integrates with Rails/Sinatra.

```ruby
class UsersApi < Joshua
  collection do
    define :login do
      desc 'Authenticate user'
      params do
        email :email
        pass String
      end
      proc do
        user = User.authenticate(params.email, params.pass)
        user ? user.token : error('Invalid credentials')
      end
    end
  end

  member do
    define :show do
      proc { User.find(@api.id).to_h }
    end
  end
end

# Routes created automatically:
# POST /api/users/login
# POST /api/users/:id/show
```

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
  collection do
    def ping
      'pong'
    end
  end
end

run ApplicationApi
```

Run with `rackup -p 3000`, then `curl http://localhost:3000/users/ping`.

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

## Defining Endpoints

Use `define :method_name do ... proc do ... end end` to define endpoints (preferred). You can also use plain `def` methods:

```ruby
collection do
  # Preferred: define block with proc
  define :login do
    desc 'Login endpoint'
    params do
      email :email
    end
    proc { User.authenticate(params.email) }
  end

  # Alternative: plain def (less visual grouping)
  desc 'Health check'
  def ping
    'pong'
  end
end
```

## Routing

Routes map directly to methods. No configuration needed.

| Route Pattern | Block Type | Example |
|--------------|------------|---------|
| `/class/method` | `collection` | `/users/login` |
| `/class/:id/method` | `member` | `/users/123/show` |

```ruby
class UsersApi < Joshua
  collection do
    define :login do      # /api/users/login
      proc { 'login' }
    end
  end

  member do
    define :show do       # /api/users/:id/show
      proc { @api.id }    # => "123"
    end
  end
end

# Namespaced classes use dots
module Admin
  class UsersApi < Joshua
    member do
      define :ban do      # /api/admin.users/:id/ban
        proc { }
      end
    end
  end
end
```

## Parameters

Define parameters inside `define` block:

```ruby
collection do
  define :signup do
    params do
      email :email                    # required email
      name String                     # required string
      age? Integer                    # optional integer
      role String, default: 'user'   # with default
      score Integer, min: 0, max: 100
    end
    proc do
      params.email  # access via dot notation
      params[:name] # or hash syntax
    end
  end
end
```

### Built-in Types

- `:string` (default), `:integer`, `:float`, `:boolean`
- `:email`, `:url`, `:date`, `:datetime`, `:hash`

### Custom Parameter Types

```ruby
class ApplicationApi < Joshua
  params :phone do |value, opts|
    error 'Invalid phone' unless value =~ /^\+?[\d\-\s]+$/
    value.gsub(/\D/, '')  # return normalized value
  end
end

class UsersApi < ApplicationApi
  collection do
    define :update_phone do
      params do
        contact_phone :phone
      end
      proc do
        # params.contact_phone is normalized
      end
    end
  end
end
```

### Array Parameters

```ruby
params do
  tags Array[:string]
  tags Array[:string], delimiter: /\s*,\s*/  # split string input
end
```

## Response Format

All responses follow a consistent structure:

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

### Response Methods

```ruby
define :update do
  proc do
    message 'User updated'           # set response message
    response[:request_id] = @api.uid # add metadata
    response.meta :version, '1.0'    # same as above

    { id: 1, name: 'foo' }           # returned value becomes data
  end
end
```

### Custom Content Types

```ruby
define :export_csv do
  proc do
    response do
      @user.to_csv  # bypasses JSON wrapper
    end
  end
end
# Returns raw CSV with text/plain content type
```

## Error Handling

```ruby
define :foo do
  proc do
    error 'Something went wrong'      # 400 status
    error 404, 'Not found'            # custom status
    error 403, 'Forbidden', code: 'ACCESS_DENIED'  # with error code
  end
end
```

### Named Errors and rescue_from

```ruby
class ApplicationApi < Joshua
  rescue_from :unauthorized, 'Authentication required'

  rescue_from ActiveRecord::RecordNotFound do |e|
    error 404, 'Record not found'
  end

  rescue_from :all do |e|
    # catch-all for unhandled exceptions
    error 500, 'Internal error'
  end
end

class UsersApi < ApplicationApi
  member do
    define :show do
      proc do
        error :unauthorized unless @current_user
        User.find(@api.id)  # raises RecordNotFound if missing
      end
    end
  end
end
```

## Lifecycle Callbacks

```ruby
class ApplicationApi < Joshua
  before do
    @current_user = User.find_by(token: @api.bearer)
  end

  after do
    response[:timestamp] = Time.now.iso8601
  end
end

class UsersApi < ApplicationApi
  member do
    before do
      # runs after ApplicationApi's before, only for member methods
      @user = User.find(@api.id)
    end

    define :show do
      proc { @user.to_h }
    end
  end
end
```

## Authentication

Bearer tokens are extracted from the `Authorization` header:

```ruby
# Request: Authorization: Bearer abc123

class ApplicationApi < Joshua
  before do
    if @api.bearer
      @current_user = User.find_by(token: @api.bearer)
      error 401, 'Invalid token' unless @current_user
    end
  end
end
```

### Unsafe Methods

Mark methods that don't require authentication:

```ruby
collection do
  define :login do
    unsafe
    proc do
      # @api.opts.unsafe == true
      # before filter can check this to skip auth
    end
  end
end
```

## Annotations

Create reusable method decorators:

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
  collection do
    define :delete_all do
      require_admin
      rate_limit 10
      proc do
        # protected by annotations
      end
    end
  end
end
```

## Models

Define reusable parameter schemas:

```ruby
class ApplicationApi < Joshua
  model :user_input do
    name String
    email :email
    role? String
  end
end

class UsersApi < ApplicationApi
  member do
    define :update do
      params do
        user model: :user_input
      end
      proc do
        @user.update(params.user)
      end
    end
  end
end
```

## HTTP Methods

By default, all endpoints accept POST only. Use RESTful syntax to specify HTTP methods:

```ruby
member do
  # Single method - symbol key syntax
  define get: :show do
    proc { }
  end

  define put: :update do
    proc { }
  end

  # Multiple methods - hash rocket required for array key
  define [:get, :put] => :settings do
    proc { }
  end

  # Alternative: allow inside block
  define :archive do
    allow :put
    proc { }
  end

  define :config do
    allow :get, :put, :delete
    proc { }
  end
end
```

## API Documentation

Enable automatic documentation:

```ruby
class UsersApi < Joshua
  documented

  collection do
    define :login do
      desc 'Authenticate user'
      detail 'Returns JWT token on success'
      params do
        email :email
        pass String
      end
      proc { }
    end
  end
end
```

Documentation available at:
- `/api` - Interactive HTML docs
- `/api/_/raw` - JSON schema
- `/api/_/postman` - Postman import URL

## JSON RPC Mode

Joshua also accepts JSON RPC style requests:

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
# => { success: true, data: 'token-abc', ... }

# Member method
result = UsersApi.render.show(123)
# => { success: true, data: { id: 123, ... }, ... }

# With bearer token
result = UsersApi.render.show(123, bearer: 'user-token')

# Alternative syntax
result = UsersApi.render(:login, params: { email: 'foo@bar.com' })
```

### RSpec Example

```ruby
RSpec.describe UsersApi do
  describe '.login' do
    it 'returns token for valid credentials' do
      result = UsersApi.render.login(email: 'test@example.com', pass: 'valid')
      expect(result[:success]).to be true
      expect(result[:data]).to be_present
    end

    it 'returns error for invalid credentials' do
      result = UsersApi.render.login(email: 'test@example.com', pass: 'wrong')
      expect(result[:success]).to be false
    end
  end
end
```

## Inheritance

API classes inherit from each other like normal Ruby:

```ruby
class ApplicationApi < Joshua
  before { @current_user = authenticate }
  after { log_request }
end

class ModelApi < ApplicationApi
  before { @model = load_model }

  member do
    define :show do
      proc { @model.to_h }
    end

    define :delete do
      proc do
        @model.destroy
        message 'Deleted'
      end
    end
  end
end

class UsersApi < ModelApi
  # inherits show, delete, and all callbacks
end

class PostsApi < ModelApi
  member do
    define :show do
      proc do
        super!  # call ModelApi's show
        # add extra logic
      end
    end
  end
end
```

## Plugins

Create reusable API modules:

```ruby
Joshua.plugin :pagination do
  def paginate(collection)
    page = (params.page || 1).to_i
    per = (params.per || 20).to_i
    collection.limit(per).offset((page - 1) * per)
  end
end

class UsersApi < Joshua
  plugin :pagination

  collection do
    define :index do
      proc { paginate(User.all).map(&:to_h) }
    end
  end
end
```

## Instance Variables

Available in API methods via `@api`:

| Variable | Description |
|----------|-------------|
| `@api.id` | Resource ID (member methods) |
| `@api.bearer` | Bearer token from Authorization header |
| `@api.action` | Current method name (symbol) |
| `@api.params` | Request parameters |
| `@api.request` | Rack request object |
| `@api.response` | Joshua response object |
| `@api.opts` | Options passed to initializer |
| `@api.development` | Development mode flag |

## Dependencies

- rack
- json
- html-tag
- hash_wia
- typero

## Development

```bash
git clone https://github.com/dux/joshua.git
cd joshua
bundle install
rspec
```

## License

MIT License
