## Ruby client for Joshua

### Usage

`require 'joshua/client'`

### Examples

```ruby
# create client
api = JoshuaClient.new 'http://localhost:4567/api', debug: true

# add credentials (if possble)
api.bearer = @user.token

# call methods in format - method, options

# call collection method
api.users.list
api.users.login({ user: 'foo', pass: 'bar' })
api.call 'users/login', user: 'foo', pass: 'bar'
api.call ['users', 'login'], user: 'foo', pass: 'bar'
api.call 'users', 'login', user: 'foo', pass: 'bar'

# call member method 
api.company(1).index({ label: 'goverment' })
api.company(1).index
api.call 'company/1/index'
api.call [:company, 1, :index]
api.call :company, 1, :index

# status and result
api.success?
api.response
```