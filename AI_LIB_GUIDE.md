# Joshua AI Library Guide

This guide helps AI agents understand, use, and write code for the Joshua Ruby API framework.

## Overview

Joshua is an opinionated API implementation for Ruby featuring:
- Automatic routing (no manual route configuration)
- REST or JSON-RPC support
- Automatic documentation generation
- Framework-agnostic (works with Rack, Sinatra, Rails, or standalone)
- Direct request-to-method mapping for maximum performance
- Built-in parameter validation with Typero
- Consistent request/response flow

## Core Architecture

### File Structure

```
lib/joshua/
├── base_class.rb      # Class-level methods (routing, params, rescue_from, etc.)
├── base_instance.rb  # Instance methods (execution, callbacks)
├── response.rb        # Response formatting
├── render_proxy.rb   # Simplified render interface
└── client.rb         # Client library reference

api/                  # Example API implementations
├── application_api.rb
├── model_api.rb
└── user_api.rb

client/               # Client libraries
├── ruby/client.rb
└── javascript/joshua_client.js
```

### Core Classes

- `Joshua` - Base class that all API classes inherit from
- `Joshua::Response` - Handles response formatting and error handling
- `Joshua::RenderProxy` - Simplified render interface for testing
- `Joshua::Error` - Custom error class

## Key Concepts

### 1. Routing Pattern

Joshua uses a **convention-over-configuration** approach:

- **Collection routes** (no resource ID): `/api/users/login`
- **Member routes** (with resource ID): `/api/users/123/show`

Routes are automatically mapped to class methods based on this pattern:
- 2 parts: `class/collection_method`
- 3 parts: `class/resource_id/member_method`

### 2. Member vs Collection Methods

```ruby
class UsersApi < Joshua
  collection do  # /api/users/login (no ID)
    def login
    end
  end

  member do      # /api/users/123/show (requires ID)
    def show
    end
  end
end
```

Key differences:
- `collection` methods: `@api.id` is nil
- `member` methods: `@api.id` contains the resource ID
- Both can define the same method names (e.g., both can have `update`)

### 3. Automatic Request Flow

```
Request → Parse → Before Callbacks → Annotations → Params Validation → Method Execution → After Callbacks → Response
```

### 4. Inheritance Pattern

Joshua encourages inheritance for code reuse:

```ruby
class ApplicationApi < Joshua
  # Define common behavior for all APIs
  before do
    @current_user = User.find_by(token: @api.bearer)
    error 'Invalid token' unless @current_user
  end
end

class ModelApi < ApplicationApi
  # Define generic CRUD operations
  member do
    def show
      @model.api_export
    end
  end
end

class UsersApi < ModelApi
  # Inherits all methods from ModelApi
  collection do
    def signup
      # Custom signup logic
    end
  end
end
```

## Writing API Classes

### Basic API Class

```ruby
class UsersApi < Joshua
  documented  # Enables auto-documentation

  collection do
    desc 'Login with email and password'
    detail 'For demo: user=foo, pass=bar'
    params do
      user String, required: true
      pass String, required: true
    end
    def login
      if params.user == 'foo' && params.pass == 'bar'
        message 'Login successful'
        'token-abcdefg'
      else
        error 'Invalid credentials'
      end
    end
  end

  member do
    desc 'Get user by ID'
    def show
      @user ||= User.find(@api.id)
      @user.api_export
    end
  end
end
```

### Class-Level Methods

#### Documentation
```ruby
class UsersApi < Joshua
  documented  # Include in auto-generated docs
  desc 'User operations'  # Class description
  detail 'Manage user accounts'  # Detailed description
  icon '<svg>...</svg>'  # SVG icon for docs
end
```

#### Error Handling
```ruby
class ApplicationApi < Joshua
  rescue_from :not_found, 'Resource not found'
  rescue_from :forbidden, 'Access denied'

  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end

  rescue_from StandardError do |error|
    logger.error error
    error 500, 'Internal server error'
  end
end
```

#### Annotations
```ruby
class ApplicationApi < Joshua
  annotation :anonymous do
    @anonymous_allowed = true
  end

  annotation :hcaptcha! do
    captcha = params['h-captcha-response'] || error('Captcha required')
    data = JSON.parse(`curl -d "response=#{captcha}&secret=#{ENV['HCAPTCHA_SECRET']}" -X POST https://hcaptcha.com/siteverify`)
    error 'Captcha failed' unless data['success']
  end
end

class UsersApi < ApplicationApi
  collection do
    anonymous  # Uses the annotation
    hcaptcha!
    def login
      # Access allowed without authentication
    end
  end
end
```

#### Callbacks
```ruby
class ApplicationApi < Joshua
  # Run before ALL methods (member and collection)
  before do
    @current_user = User.find_by(token: @api.bearer)
    @start_time = Time.now
  end

  # Run after ALL methods
  after do
    response[:speed] = ((Time.now - @start_time) * 1000).round(2)
  end
end

class UsersApi < ApplicationApi
  collection do
    # Run only before collection methods
    before do
      @log_message = 'Collection access'
    end

    after do
      logger.info @log_message
    end

    def index
      User.all.map(&:api_export)
    end
  end

  member do
    # Run only before member methods
    before do
      @model = User.find(@api.id)
    end

    def show
      @model.api_export
    end
  end
end
```

#### Parameters
```ruby
class UsersApi < Joshua
  collection do
    params do
      # Basic string param (required by default)
      email :email

      # Optional param (ends with ?)
      phone? String

      # With validation
      age Integer, min: 18, max: 120, required: true

      # With default
      limit Integer, default: 20, max: 100

      # Boolean
      is_admin? :boolean

      # Array/Set types
      tags Array[:tag]
      unique_tags Set[:tag]

      # Custom delimiter for array
      tags Array[:tag], delimiter: /\s*,\s*/
    end

    def search
      # Use params via params.email, params.age, etc.
      # params.to_h returns hash
    end
  end
end
```

#### Custom Param Types
```ruby
class ApplicationApi < Joshua
  params :locale do |value, opts|
    # Validate and coerce
    error 'Invalid locale format' unless value =~ /^[a-z]{2}(-[a-z]{2})?$/i
    value.downcase
  end
end

class SettingsApi < ApplicationApi
  collection do
    params do
      user_locale :locale
    end

    def update_locale
      # params.user_locale is validated and coerced
    end
  end
end
```

#### Models
```ruby
class ApplicationApi < Joshua
  model User do
    name String
    email :email
    is_admin? :boolean

    # Validation logic before assignment
    proc do |data|
      if !data[:is_admin].nil? && !@current_user&.admin?
        error 'Cannot modify admin flag'
      end
    end
  end
end

class UsersApi < ApplicationApi
  member do
    params do
      user model: User  # Validates against User model
    end

    def update
      @user.update(params.user.to_h)
      message 'User updated'
      @user.api_export
    end
  end
end
```

#### Method-Level Options
```ruby
class UsersApi < Joshua
  collection do
    # Allow GET request (default is POST only)
    allow :get
    def index
      User.all
    end

    # Allow GET in development mode only
    def list
      User.all
    end

    # Mark as unsafe (no bearer token required)
    unsafe
    def login
    end

    # Custom content type
    content_type :text
    def export
      "csv data..."
    end
  end
end
```

### Instance Methods (Inside API Methods)

#### Available Variables
```ruby
def show
  # @api provides access to:
  @api.action        # Current method name (:show)
  @api.bearer        # Bearer token from Authorization header
  @api.development   # Boolean: development mode?
  @api.id            # Resource ID (member methods only)
  @api.request       # Rack::Request object
  @api.response      # Joshua::Response object
  @api.method_opts   # Method options (desc, params, etc.)
  @api.api_host      # API host object (for integration)
end
```

#### Response Methods
```ruby
def update
  # Set response message
  message 'Update successful'

  # Set meta data
  response[:ip] = @api.request.ip
  response.meta :speed, 123  # Same as above

  # Set headers
  response.header['X-Custom-Header'] = 'value'

  # Set custom response data
  response.data = { foo: 'bar' }

  # Check for errors
  if response.error?
    # Handle errors
  end

  # Return data (becomes response.data)
  { updated: true }
end
```

#### Error Handling
```ruby
def delete
  # Simple error (400)
  error 'Object not found'

  # Error with code (404)
  error 404, 'Object not found'

  # Trigger named error
  error :not_found

  # Error with status and custom fields
  error 'Validation failed', status: 422, details: { email: 'Invalid' }
end
```

#### Accessing Params
```ruby
def create
  # Access individual params
  email = params.email

  # Get as hash
  data = params.to_h

  # Check if param present
  if params.has_key?(:admin)
    # ...
  end
end
```

#### Calling Super Methods
```ruby
class ParentApi < Joshua
  collection do
    def process
      100
    end
  end
end

class ChildApi < ParentApi
  collection do
    def process
      super!  # Call parent's process method (100)
      200     # Add to it
    end

    def other
      process  # Returns 300 (child's version)
      super! :process  # Returns 100 (parent's version)
    end
  end
end
```

## Testing

### Basic Testing with Render

```ruby
# Collection method
result = UsersApi.render.login(user: 'foo', pass: 'bar')
# => { success: true, data: 'token-...', message: 'Login ok' }

# Member method
result = UsersApi.render.show(123, bearer: 'token-xyz')
# => { success: true, data: { ... } }

# With full options
result = UsersApi.render :update,
  id: 123,
  bearer: 'token-xyz',
  params: { email: 'new@email.com' }
```

### RSpec Example

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
      expect(result[:message]).to eq('Login ok')
    end

    it 'returns error for invalid credentials' do
      result = UsersApi.render.login(user: 'wrong', pass: 'wrong')

      expect(result[:success]).to be false
      expect(result[:error][:messages]).to include('Invalid credentials')
    end
  end

  describe 'GET /users/:id/show' do
    it 'returns user data' do
      result = UsersApi.render.show(user.id, bearer: user.token)

      expect(result[:success]).to be true
      expect(result[:data][:email]).to eq(user.email)
    end
  end
end
```

## Integration

### Standalone Rack (config.ru)

```ruby
require 'joshua'

class ApplicationApi < Joshua
  before do
    response.header['Access-Control-Allow-Origin'] = '*'
  end
end

class UsersApi < ApplicationApi
  collection do
    def login
    end
  end
end

run ApplicationApi
# Access at: http://localhost:9292/users/login
```

### Sinatra Integration

```ruby
require 'sinatra'
require 'joshua'

class ApplicationApi < Joshua
end

# Mount API
post '/api*' do
  ApplicationApi.auto_mount(
    mount_on: '/api',
    request: request,
    response: response,
    development: settings.development?
  )
end

# Documentation route
get '/api' do
  ApplicationApi.auto_mount(
    mount_on: '/api',
    request: request,
    response: response,
    development: settings.development?
  )
end
```

### Rails Integration

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ApplicationApi => '/api'
end

# app/controllers/application_api.rb
class ApplicationApi < Joshua
  before do
    @current_user = User.find_by(token: @api.bearer)
  end
end

# app/api/users_api.rb
class UsersApi < ApplicationApi
  collection do
    def login
    end
  end
end
```

## Best Practices

### 1. Use Inheritance for Common Logic

```ruby
# Good: Inherit common behavior
class ModelApi < ApplicationApi
  member do
    before do
      @model = self.class.name.sub(/Api$/, '').singularize.constantize.find(@api.id)
    end
  end
end

# Bad: Repeat code in every class
class UsersApi < ApplicationApi
  member do
    before do
      @model = User.find(@api.id)
    end
  end
end

class CompaniesApi < ApplicationApi
  member do
    before do
      @model = Company.find(@api.id)
    end
  end
end
```

### 2. Define Named Errors for Consistency

```ruby
class ApplicationApi < Joshua
  rescue_from :not_found, 'Resource not found'
  rescue_from :forbidden, 'Access denied'
  rescue_from :validation, 'Validation failed'

  rescue_from Policy::Error do |error|
    error 403, 'Policy error: %s' % error.message
  end
end

class UsersApi < ApplicationApi
  member do
    def show
      @user = User.find(@api.id)
      error :not_found unless @user
      @user.api_export
    end
  end
end
```

### 3. Use Annotations for Cross-Cutting Concerns

```ruby
class ApplicationApi < Joshua
  annotation :rate_limit do
    limit = @current_user ? 100 : 10
    key = "rate_limit:#{@api.request.ip}:#{Time.now.to_i / 60}"
    count = Redis.current.incr(key)
    Redis.current.expire(key, 60) if count == 1
    error 'Rate limit exceeded' if count > limit
  end
end

class UsersApi < ApplicationApi
  collection do
    rate_limit
    def signup
    end
  end
end
```

### 4. Validate Params Before Method Body

```ruby
class UsersApi < Joshua
  collection do
    params do
      email :email, required: true
      password String, min: 8, required: true
    end

    def signup
      # Params already validated, no need to check again
      user = User.create(params.to_h)
      message 'User created'
      user.api_export
    end
  end
end
```

### 5. Use `super!` for Method Inheritance

```ruby
class ParentApi < Joshua
  member do
    before do
      @parent_data = 'parent'
    end

    def update
      @model.update(params.to_h)
      message 'Updated'
    end
  end
end

class ChildApi < ParentApi
  member do
    before do
      super!  # Run parent's before callback
      @child_data = 'child'
    end

    def update
      super!  # Run parent's update logic
      # Add child-specific logic
    end
  end
end
```

### 6. Use Helper Methods for Reusability

```ruby
class ApplicationApi < Joshua
  # Helper method (not in collection/member)
  def user
    @current_user || error('Authentication required')
  end

  def admin?
    user.admin?
  end
end

class UsersApi < ApplicationApi
  member do
    def sensitive_action
      error :forbidden unless admin?
      # ...
    end
  end
end
```

## Common Patterns

### Authentication

```ruby
class ApplicationApi < Joshua
  before do
    if @api.bearer
      @current_user = User.find_by(token: @api.bearer)
      error 'Invalid token' unless @current_user
    end
  end

  annotation :public do
    @public_access = true
  end

  before do
    error 'Authentication required' unless @current_user || @public_access
  end
end

class UsersApi < ApplicationApi
  collection do
    public  # No auth required
    unsafe
    def login
    end
  end

  member do
    def show  # Auth required
      user.api_export
    end
  end
end
```

### Pagination

```ruby
class ApplicationApi < Joshua
  annotation :paginated do
    @page = (params.page || 1).to_i
    @per_page = [params.per_page || 20, 100].min
  end
end

class UsersApi < ApplicationApi
  collection do
    params do
      page? Integer, default: 1
      per_page? Integer, default: 20
    end

    paginated
    def index
      users = User.limit(@per_page).offset((@page - 1) * @per_page)
      {
        data: users.map(&:api_export),
        meta: {
          page: @page,
          per_page: @per_page,
          total: User.count
        }
      }
    end
  end
end
```

### File Upload

```ruby
class FilesApi < ApplicationApi
  collection do
    params do
      file Hash  # Rack::Multipart::UploadedFile
      description? String
    end

    def upload
      file = params.file
      error 'No file provided' unless file
      error 'File too large' if file[:tempfile].size > 10.megabytes

      filename = SecureRandom.hex + File.extname(file[:filename])
      path = Rails.root.join('uploads', filename)

      File.open(path, 'wb') do |f|
        f.write(file[:tempfile].read)
      end

      { url: "/uploads/#{filename}", size: file[:tempfile].size }
    end
  end
end
```

### Response Format Variations

```ruby
class ReportsApi < ApplicationApi
  collection do
    # JSON response (default)
    def json_report
      { data: '...' }
    end

    # CSV response
    def csv_report
      response do
        "name,email\nfoo,bar@baz.com"
      end
    end

    # Custom content type
    content_type :text
    def text_report
      "Plain text report"
    end
  end
end
```

## Response Format

### Success Response
```json
{
  "success": true,
  "message": "Operation successful",
  "data": { /* result data */ },
  "meta": {
    "ip": "127.0.0.1",
    "speed": 12.5
  },
  "status": 200
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "messages": ["Invalid email format"],
    "details": {
      "email": "Invalid email format"
    },
    "code": 400
  },
  "status": 400
}
```

## Documentation

Joshua automatically generates documentation at the mount point:
- HTML docs: `GET /api`
- Raw JSON: `GET /api/_/raw`
- Postman import: `GET /api/_/postman`

To include a class in documentation, add `documented`:

```ruby
class UsersApi < Joshua
  documented
  # ...
end
```

## Client Usage

### Ruby Client

```ruby
require 'joshua_client'

api = JoshuaClient.new('http://localhost:9292/api')

# Collection method
result = api.users.login(user: 'foo', pass: 'bar')

# Member method
result = api.users(1).show

# Generic call
result = api.call('users/1/show')
result = api.call(:users, 1, :show)
```

### JavaScript Client

```javascript
// Collection method
Api('users/login', { user: 'foo', pass: 'bar' })
  .done(function(response) {
    console.log('Success:', response);
  })
  .error(function(error) {
    console.error('Error:', error);
  });

// Member method
Api('users/1/show')
  .done(function(response) {
    // handle success
  });
```

## Troubleshooting

### Common Issues

1. **"API method not found"**
   - Ensure method is defined within `collection` or `member` block
   - Check method name matches exactly (case-sensitive)

2. **Bearer token not working**
   - Ensure token is passed in `Authorization: Bearer <token>` header
   - Check `@api.bearer` in before block

3. **Params validation failing**
   - Define params block before method definition
   - Check param types and validation rules

4. **Super method not found**
   - Use `super!` instead of `super` for API methods
   - Ensure parent class has the method

### Debug Mode

Enable development mode for detailed error messages:

```ruby
ApplicationApi.auto_mount(
  development: true,  # Shows full stack traces
  # ...
)

# Or in tests
result = UsersApi.render :login,
  params: { user: 'foo', pass: 'bar' },
  development: true
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/tests/basic_spec.rb

# Run console for debugging
rake console
```

## Advanced Topics

### Custom Mount Points

```ruby
class ApplicationApi < Joshua
  after_auto_mount do |path_parts, opts|
    # Transform /api/cisco/contracts/list
    # to /api/contracts/list?org_id=123
    if org = Org.find_by(code: path_parts.first)
      path_parts.shift
      opts[:params][:org_id] = org.id
    end
  end
end
```

### Plugin System

```ruby
# Define a plugin
Joshua.plugin :auth do
  collection do
    def current_user
      @current_user ||= User.find_by(token: @api.bearer)
    end
  end
end

# Use plugin in API class
class UsersApi < Joshua
  plugin :auth

  collection do
    def profile
      current_user.api_export
    end
  end
end
```

### Module Include Pattern

```ruby
module ApiHelpers
  def self.included(base)
    base.collection do
      def timestamp
        Time.now.to_i
      end
    end
  end
end

class UsersApi < Joshua
  include ApiHelpers

  collection do
    def login
      { time: timestamp }
    end
  end
end
```

## Reference

### Key Files

- `lib/joshua/base_class.rb` - Class methods (routing, params, callbacks)
- `lib/joshua/base_instance.rb` - Instance methods (execution flow)
- `lib/joshua/response.rb` - Response formatting
- `lib/joshua/render_proxy.rb` - Simplified testing interface

### Class Variables (Global State)

- `Joshua::DOCUMENTED` - Array of documented API classes
- `Joshua::RESCUE_FROM` - Hash of error handlers
- `Joshua::ANNOTATIONS` - Hash of annotation blocks
- `Joshua::OPTS` - Nested hash of API options
- `Joshua::PLUGINS` - Hash of plugin blocks

### Dependencies

- `rack` - HTTP request/response
- `json` - JSON serialization
- `typero` - Parameter validation
- `hash_wia` - Indifferent access hashes
- `html-tag` - Documentation HTML generation
- `dry-inflector` - String inflection (classify, etc.)

## Summary

When writing code for Joshua:

1. **Inherit from Joshua** (or a parent API class)
2. **Use collection/member blocks** to define API methods
3. **Define params before methods** for validation
4. **Use documented** to include in auto-generated docs
5. **Leverage inheritance** with `super!` for code reuse
6. **Use annotations** for cross-cutting concerns
7. **Test with `.render.method_name()`** for easy testing
8. **Follow naming conventions** (ClassApi for classes, collection/member for scopes)
