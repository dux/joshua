## Joshua - real life example

In this more complex example

* `ApplicationApi` loads current user from `@api.bearer` token
* `ModelApi` is a base for all models. `@object` is created and generic representation of object in place
* `UserApi` inherits from `ModelApi` and generated methods via `generate`. For user only `:show` and `:update` is generated
* Security is checked via `https://github.com/dux/clean-policy`. Before every update, delete we check if user can do it `@object.can.update!`