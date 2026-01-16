## What Joshua Is

Joshua is a Ruby API framework that maps HTTP requests directly to Ruby methods. No routing configuration needed. It can run standalone on Rack or integrate with Rails/Sinatra.

## Core Concepts

### 1. API Class Structure

Every API class inherits from `Joshua` or another API class. Use `define :name do ... proc do ... end end` to define endpoints:

```ruby
class UsersApi < Joshua
  # collection = endpoints WITHOUT resource ID (/users/login)
  collection do
    define :login do
      desc 'User login'
      params do
        email :email
        pass String
      end
      proc do
        User.authenticate(params.email, params.pass)
      end
    end
  end

  # member = endpoints WITH resource ID (/users/123/show)
  member do
    define :show do
      proc { User.find(@api.id).to_h }
    end
  end

  # methods outside blocks = helper methods (not endpoints)
  def helper
  end
end
```

Alternative: plain `def` methods also work (but `define` is preferred for visual grouping):

```ruby
collection do
  desc 'Health check'
  def ping
    'pong'
  end
end
```

### 2. Route Mapping

| Pattern | Block | Route Example |
|---------|-------|---------------|
| 2 parts | `collection` | `/api/users/login` |
| 3 parts | `member` | `/api/users/123/show` |

Class name `UsersApi` becomes route prefix `users`. Namespaced `Admin::UsersApi` becomes `admin.users`.

### 3. Parameters

Define params inside `define` block:

```ruby
collection do
  define :signup do
    params do
      email :email           # required
      name String            # required string
      age? Integer           # optional (? suffix)
      role String, default: 'user'
    end
    proc do
      params.email           # dot notation
      params[:name]          # hash notation
    end
  end
end
```

Types: `:string`, `:integer`, `:float`, `:boolean`, `:email`, `:url`, `:date`, `:datetime`, `:hash`

### 4. Responses

Methods return data directly. Use helpers for messages/errors:

```ruby
define :update do
  proc do
    message 'Updated'              # sets response message
    response[:meta_key] = 'value'  # adds metadata
    { id: 1, name: 'foo' }         # return value = response data
  end
end

define :failing do
  proc do
    error 'Something wrong'        # 400 error
    error 404, 'Not found'         # custom status
  end
end
```

Response format:
```ruby
{ success: true, data: ..., message: ..., meta: {...} }
{ success: false, error: { messages: [...], details: {...} } }
```

### 5. Callbacks

```ruby
class ApplicationApi < Joshua
  before do
    @current_user = User.find_by(token: @api.bearer)
  end

  after do
    response[:timestamp] = Time.now
  end
end
```

Callbacks in `member`/`collection` blocks only run for those method types.

### 6. Error Handling

```ruby
class ApplicationApi < Joshua
  rescue_from :not_allowed, 'Not allowed'

  rescue_from ActiveRecord::RecordNotFound do |e|
    error 404, 'Not found'
  end
end

# Usage in methods:
define :foo do
  proc do
    error :not_allowed           # triggers named rescue
    error 'Direct error'         # immediate error
  end
end
```

### 7. Authentication

Bearer token from `Authorization: Bearer xxx` header:

```ruby
before do
  @current_user = User.find_by(token: @api.bearer) if @api.bearer
end
```

Mark public methods with `unsafe`:

```ruby
collection do
  define :login do
    unsafe
    proc do
      # @api.opts.unsafe == true, skip auth in before block
    end
  end
end
```

### 8. Annotations

Custom method decorators:

```ruby
annotation :admin_only do
  error 403, 'Admin required' unless @current_user&.admin?
end

collection do
  define :delete_all do
    admin_only
    proc { }
  end
end
```

### 9. HTTP Methods

Default is POST only. Use RESTful syntax to specify HTTP methods:

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

### 10. Documentation

```ruby
class UsersApi < Joshua
  documented  # enables auto-docs

  collection do
    define :login do
      desc 'Login endpoint'
      detail 'Returns JWT token'
      params do
        email :email
      end
      proc { }
    end
  end
end
```

Docs at `/api`, JSON at `/api/_/raw`, Postman at `/api/_/postman`.

## Instance Variable Reference

Access via `@api`:

- `@api.id` - resource ID (member methods)
- `@api.bearer` - bearer token
- `@api.action` - method name (symbol)
- `@api.params` - parameters
- `@api.request` - Rack request
- `@api.response` - response object
- `@api.opts` - options hash
- `@api.development` - dev mode flag

## Testing APIs

Call directly without HTTP:

```ruby
UsersApi.render.login(email: 'a@b.com', pass: 'secret')
UsersApi.render.show(123)
UsersApi.render.show(123, bearer: 'token')
```

## Common Patterns

### Base API with Auth

```ruby
class ApplicationApi < Joshua
  before do
    return if @api.opts.unsafe
    @current_user = User.find_by(token: @api.bearer)
    error 401, 'Unauthorized' unless @current_user
  end
end
```

### Model API with Auto-loading

```ruby
class ModelApi < ApplicationApi
  before do
    if @api.id
      klass = self.class.name.sub(/Api$/, '').constantize
      @model = klass.find(@api.id)
    end
  end

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
  # inherits show, delete
end
```

### Custom Parameter Type

```ruby
class ApplicationApi < Joshua
  params :phone do |value, opts|
    error 'Invalid phone' unless value =~ /^\d{10}$/
    value  # return (possibly transformed) value
  end
end
```

### Pagination Helper

```ruby
class ApplicationApi < Joshua
  def paginate(scope)
    page = (params.page || 1).to_i
    per = (params.per || 20).to_i
    scope.limit(per).offset((page - 1) * per)
  end
end
```

## Do NOT

- Define API methods outside `member`/`collection` blocks (they become helpers, not endpoints)
- Forget to end `define` blocks with `proc do ... end`
- Use `super` in API methods (use `super!` instead)
- Use `def` when you need annotations/params/desc in the same block (use `define` instead)

## File Structure

```
app/
  api/
    application_api.rb    # base class
    users_api.rb          # UsersApi < ApplicationApi
    posts_api.rb          # PostsApi < ApplicationApi
```

## Integration

### Rails

```ruby
# routes.rb
match '/api/*path', to: 'api#handle', via: [:get, :post]

# api_controller.rb
def handle
  ApplicationApi.auto_mount(
    mount_on: '/api',
    api_host: self,
    bearer: current_user&.token
  )
end
```

### Standalone Rack

```ruby
# config.ru
require 'joshua'
require_relative 'api/application_api'

run ApplicationApi
```
