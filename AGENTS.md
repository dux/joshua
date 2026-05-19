## What Joshua Is

Joshua is a Ruby API framework that maps HTTP requests directly to Ruby methods. No routing configuration needed. It can run standalone on Rack or integrate with Rails/Sinatra.

## Core Concepts

### 1. API Class Structure

Every API class inherits from `Joshua` or another API class.

* Public methods at the class root are **collection** endpoints (no resource id) - hit at `/api/users/login`.
* Public methods defined inside `ref do ... end` are **member** endpoints (with a resource id) - hit at `/api/users/123/show`. Each one is renamed internally to `<name>_ref`.
* `private` methods are NEVER exposed as endpoints - they remain callable helpers.

```ruby
class UsersApi < Joshua
  # collection action - /users/login
  unsafe
  params do
    email :email
    pass String
  end
  desc 'User login'
  def login
    User.authenticate(params.email, params.pass)
  end

  # ref/member action - /users/123/show
  ref do
    before do
      @user = User.find(@ref) or error 'Not found'
    end

    def show
      @user.to_h
    end
  end

  # private helpers (never reachable as endpoints)
  private

  def normalize_email str
    str.to_s.strip.downcase
  end
end
```

`define :name do ... proc do ... end end` also works at root (collection) or inside `ref do` (member):

```ruby
define :signup do
  desc 'Email signup'
  params { email :email }
  proc do
    User.create(email: params.email)
  end
end

ref do
  define :avatar do
    params { file Hash }
    proc { upload_avatar(params.file) }
  end
end
```

### 2. Route Mapping

| URL pattern              | Where the method lives          |
|--------------------------|----------------------------------|
| `/api/users/login`       | public method at class root      |
| `/api/users/123/show`    | public method inside `ref do`    |

Class name `UsersApi` becomes route prefix `users`. Namespaced `Admin::UsersApi` becomes `admin.users`.

### 3. Convenience instance variables

Available inside every action body and every callback:

* `@ref`          - the resource id portion of the URL (member only; nil for collection).
* `@bearer_token` - the `Authorization: Bearer ...` token.

`@api` is still the canonical accessor (`@api.id`, `@api.bearer`, `@api.action`, `@api.params`, `@api.request`, `@api.response`, `@api.opts`, `@api.development`). The two new ivars just mirror `@api.id` / `@api.bearer` for convenience.

### 4. Parameters

```ruby
params do
  email :email            # required (Typero type)
  name String             # required string
  age? Integer            # optional (? suffix)
  role String, default: 'user'
end
def signup
  params.email            # dot notation
  params[:name]           # hash notation
end
```

Types: `:string`, `:integer`, `:float`, `:boolean`, `:email`, `:url`, `:date`, `:datetime`, `:hash`, plus Typero's built-ins (`:label`, `:slug`, `:phone`, `:oib`, `:iban`, ...).

### 5. Responses

Return data directly. Use helpers for messages / errors:

```ruby
def update
  message 'Updated'              # response message
  response[:meta_key] = 'value'  # adds metadata
  { id: 1, name: 'foo' }         # return value -> response data
end

def failing
  error 'Something wrong'        # 400 error
  error 404, 'Not found'         # custom status
end
```

Wire format:

```ruby
{ success: true,  data: ..., message: ..., meta: {...} }
{ success: false, error: { messages: [...], details: {...} } }
```

### 6. Callbacks

```ruby
class ApplicationApi < Joshua
  # root callbacks - fire for BOTH collection and ref actions
  before do
    @current_user = User.find_by(token: @bearer_token) if @bearer_token
  end

  after do
    response[:timestamp] = Time.now
  end

  ref do
    # ref-scoped callback - fires only for member actions
    before do
      @resource = SomeModel.find(@ref)
    end
  end
end
```

### 7. Error Handling

```ruby
class ApplicationApi < Joshua
  rescue_from :not_allowed, 'Not allowed'

  rescue_from ActiveRecord::RecordNotFound do |e|
    error 404, 'Not found'
  end
end

def foo
  error :not_allowed   # triggers named rescue
  error 'Direct error' # immediate error
end
```

### 8. Authentication

Bearer token comes from `Authorization: Bearer xxx`:

```ruby
before do
  @current_user = User.find_by(token: @bearer_token) if @bearer_token
end
```

Mark public methods with `unsafe`:

```ruby
unsafe
def login
  # @api.method_opts[:unsafe] == true - parent `before` can skip auth
end
```

### 9. Annotations

```ruby
annotation :admin_only do
  error 403, 'Admin required' unless @current_user&.admin?
end

admin_only
def delete_all
end
```

### 10. HTTP methods

Default is POST. Use RESTful syntax to allow others:

```ruby
define get: :show do
  proc { ... }
end

define put: :update do
  proc { ... }
end

# multiple methods for one action - hash rocket needed for array key
define [:get, :put] => :settings do
  proc { ... }
end

# allow inside the body works too
define :archive do
  allow :put
  proc { ... }
end

allow :get, :put, :delete
def config
  ...
end
```

### 11. Documentation

```ruby
class UsersApi < Joshua
  documented
  class_desc 'User operations'  # class-level
  class_detail 'Long description for the whole class'
  icon '<svg>...</svg>'

  desc 'Login endpoint'         # per-method (consumed by next def/define)
  detail 'Returns JWT token'
  params { email :email }
  def login
  end
end
```

Docs at `/api`, JSON at `/api/_/raw`, Postman at `/api/_/postman`.

## Testing APIs

Call directly without HTTP:

```ruby
UsersApi.render.login(email: 'a@b.com', pass: 'secret')
UsersApi.render.show(123)                  # member - id first
UsersApi.render.show(123, bearer: 'tok')
```

## Common Patterns

### Base API with Auth

```ruby
class ApplicationApi < Joshua
  before do
    return if @api.method_opts[:unsafe]
    @current_user = User.find_by(token: @bearer_token)
    error 401, 'Unauthorized' unless @current_user
  end
end
```

### Model API with Auto-loading

```ruby
class ModelApi < ApplicationApi
  before do
    if @ref
      klass = self.class.name.sub(/Api$/, '').constantize
      @model = klass.find(@ref)
    end
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
  # inherits show, delete as member actions
end
```

### Pagination Helper

```ruby
class ApplicationApi < Joshua
  private  # everything below is helper, not an endpoint

  def paginate(scope)
    page = (params.page || 1).to_i
    per  = (params.per  || 20).to_i
    scope.limit(per).offset((page - 1) * per)
  end
end
```

### Inheritance + super

```ruby
class ParentApi < Joshua
  def list
    [{ id: 1 }]
  end

  ref do
    def show
      { name: 'parent' }
    end
  end
end

class ChildApi < ParentApi
  # collection: plain Ruby super works
  def list
    super + [{ id: 2 }]
  end

  # ref: use `super!` (plain super breaks after the `_ref` rename)
  ref do
    def show
      base = super!
      base.merge(extra: true)
    end
  end
end
```

## Do NOT

* Forget to mark non-endpoint helpers as `private` - any public method at class root becomes a collection endpoint.
* Forget to end `define` blocks with `proc do ... end`.
* Use plain `super` inside `ref do` methods - use `super!` instead (UnboundMethod#define_method breaks `super` after the rename).
* Use `def` when you need annotations/params/desc as a sibling DSL inside an inline body (those work next to either `def` or `define`).

## File Structure

```
app/
  api/
    application_api.rb    # base class with before/after, rescue_from
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

## Canonical reference

`spec/api/kitchen_sink_api.rb` + `spec/tests/kitchen_sink_spec.rb` exercise every DSL feature in one place. Use it as the single source of truth for the current syntax.
