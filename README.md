# Clean API

Api implementation for [Ruby](https://www.ruby-lang.org/en/) based clients, [rack](https://github.com/rack/rack) based.

* Can work in REST or JSON RPC mode.
* requests are mapped to ruby methods, routing not needed (fast and automatic). `'/api/v1/orgs/list' # V1::OrgsApi.call(:list)`
* consistent and predictable request and response flow

##### Example api look and feel

```ruby
# can inherit from
class ModelApi < CleanApi
  rescue_from :all do |error|
    # ...
  end

  # before every request in ModelApi and all descendant classes
  before {}
  after do
    # add meta response to every request
    reponse[:ip] = request.remote_ip
  end
end

class UserApi < ModelApi
  # before evey request in UserApi
  before do
    # load current user based on
  end

  # member rotues are for members
  # /api/user/1/show
  member do
  # before evey request in UserApi but only for members
    before do
      # all api parameters are in @api struct instance, not to pollute you app
      @user = User.find(@api.id)
    end

    # you can define params directly or within a block
    params.full_info false # params { full_info :boolean, default: false }
    def show
      @user.export_as_json
    end
  end

  # member rotues are for collections, non-members
  # /api/user/login?user=foo&pass=bar
  collection do
    params do
      user!
      pass!
    end
    def login
      if params.user == 'foo' && params.pass == 'bar'
        message 'login ok'
      else
        error 'Wrong user or pass'
      end
    end
  end

  # this will not collide with member show method
  # you can call this method from member show method
  def show
  end
end

# Example request with response
UserApi.call :login, params: { user: 'foo', pass: 'bar' }
# { success: true, message: 'login ok', meta: { ip: '127.0.0.1' } }

UserApi.call :login, params: { user: 'aaa', pass: 'bbb' }
# { success: false, error: { messages: ['Wrong user or pass'] }, meta: { ip: '127.0.0.1' } }
```

## Params

You can define params directly on the parmas object or you can pass a block

* every param can have `default:` value if `blank?`
* every param can have `required: true` of default `false` (shorcut `req:`)
* param errors are [localized](./params/type_errors.rb)

```ruby
params do
  # withot params defaults to String, required: false
  full_name                                # the same
  full_name String, { required: false }    # default

  # if you add bang, it becomes required true
  full_name! # String, { required: true}  # the same

  # supported types with options
  # boolean
  is_active :boolean # { type: :boolean, default: false }
  is_active false    # { type: :boolean, default: false }
  is_active true     # { type: :boolean, default: true }

  # other
  amount  Float, { min: [5, '$5 is minimal purchase'], max: 500 }
  date1   Date      # { min: ..., max: ... }
  date2   DateTime  # { min: ..., max: ... }
  count   Integer   # { min: ..., max: ... }
  weight  Float     # { min: ..., max: ... }
  email   :email
  email   :url
end
def example1

end

def example1

end
```