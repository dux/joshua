# Joshua refactor - Step 1: gem-local changes (branch `refactor`)

## Goal

Drop the `collection do ... end` / `member do ... end` DSL in the Joshua gem and adopt the lux-fw controller pattern. **This step only changes the Joshua gem itself** (lib + demo APIs + specs + docs). All lux app migrations happen in Step 2 (`refactor-step-2.md`) after we confirm this works.

Workflow:

1. Create branch `refactor` in `~/dev/dux/gems/joshua`.
2. Land all changes below in that branch.
3. Verify Joshua's own spec suite + manual sanity check on `bin/joshua` and demos.
4. Wait for user confirmation that it works.
5. Merge `refactor` -> `master`.
6. Proceed to Step 2 (lux app migration), guided by `refactor-step-2.md`.

## Target DSL (after Step 1 lands)

* Collection actions = plain public methods at class root.
* Member actions = public methods defined inside `ref do ... end`; each is renamed to `<name>_ref` after the block.
* Helpers = methods marked `private` (at root or inside `ref do`). Private methods are never reachable from the HTTP API.
* `define :name do ... proc do ... end end` continues to work, with the same scoping rules as `def` (root = collection, inside `ref do` = `_ref`).

Two new convenience ivars exposed before any action runs:

* `@ref`          = the resource id (member URL segment, mirrors `@api.id`).
* `@bearer_token` = the bearer token (mirrors `@api.bearer`).

HTTP request/response shape and the `XApi.render.action(...)` call surface do not change.

### Example

```ruby
class UsersApi < ApplicationApi
  documented
  desc 'User operations'

  before do
    @current_user = User.find_by(token: @bearer_token) if @bearer_token
  end

  desc 'List users'
  params { q? String }
  def list
    User.search(params.q).map(&:export)
  end

  unsafe
  def login
    # ...
  end

  define :signup do
    params { email :email; pass }
    proc { User.create email: params.email, pass: params.pass }
  end

  ref do
    before do
      @user = User.find(@ref) or error 'Not found'
    end

    desc 'Show a user'
    def show              # becomes :show_ref after this block
      @user.export
    end

    def update            # becomes :update_ref
      @user.update params.to_h
      @user.export
    end

    define :avatar do     # becomes :avatar_ref
      params { file Hash }
      proc { upload_avatar params.file }
    end

    private

    def upload_avatar f   # becomes :upload_avatar_ref (private helper)
    end
  end

  private

  def display_name
    'foo'
  end
end
```

Request mapping (unchanged):

* `POST /api/users/list`            -> `:list`
* `POST /api/users/123/show`        -> `:show_ref` (with `@ref = "123"`)
* `POST /api/users/123/update`      -> `:update_ref`

## Decisions taken

* `member`/`members`/`collection`/`collections` block DSL is **removed** (no alias compat).
* Root `before do` / `after do` fires for **all** actions (collection + member). Use `ref do before do ... end ... end` to scope to member only.
* All methods defined inside `ref do` get the `_ref` suffix, including private helpers (lux-fw parity).
* `@ref` / `@bearer_token` are convenience mirrors of `@api.id` / `@api.bearer`. `@api` stays untouched.

## Internal architecture changes

### 1. `Joshua.ref(&block)` class macro

* Snapshot `instance_methods(false) + private_instance_methods(false)` before `class_eval(&block)`.
* Inside the block, set `@method_type = :member` so `before`/`after`/`params`/`desc`/`define`/`unsafe`/`allow`/annotation calls register under `:member`.
* After the block:
  * For every newly added method `n` that does not already end with `_ref`:
    * If it's a redefinition of an existing method, restore the outer impl and define `:<n>_ref` from the inner.
    * Otherwise rename `n` to `<n>_ref`, preserving visibility (public/private).
  * Reset `@method_type = nil`.
* `method_added` inside `ref do` records the action under `OPTS[class][:member][<name>]` using the **pre-rename** name, so docs and dispatch still address the action as `:show`, not `:show_ref`.

### 2. `method_added` simplified

* `@method_type == :member` (inside `ref do`): record opts under `OPTS[class][:member][name]`. Do NOT alias or remove. Renaming happens in `ref do` epilogue.
* `@method_type == nil` AND method is public (`!private_method_defined? && !protected_method_defined?`): record opts under `OPTS[class][:collection][name]`.
* Method is private/protected: discard pending `@@opts` (so leftover desc/params from a previous method don't leak), do not register.
* Skip names ending in `_ref` (produced by the rename - must not re-register).
* No more `_api_<type>_<name>` aliasing; no `remove_method`.

### 3. Dispatch in `Joshua#resolve_api_body`

```ruby
type   = @ref ? :member : :collection
opts   = self.class.opts.dig(type, @api.action) or
           raise Joshua::Error, "Api method #{type}:#{@api.action} not found"
method = @ref ? "#{@api.action}_ref" : @api.action.to_s
send method
```

Lookup is via the OPTS registry (only registered, public-at-define-time actions). This blocks accidental exposure of inherited internal methods like `to_h`, `to_json`, `execute_call`.

### 4. New ivars set in `initialize`

```ruby
@ref          = @api.id
@bearer_token = @api.bearer
```

Set before any `before` callback runs.

### 5. `super!` compatibility

After the rename, plain Ruby `super` works inside `<name>_ref` (no aliasing in the way). Keep `super!` as a thin shim that resolves to the equivalent `super` call (look up `name` or `name_ref` on the superclass based on `@ref`) so nothing in tests/demos breaks. Document `super` as preferred in the docs.

### 6. Plugin / module include pattern

Old form:

```ruby
def self.included base
  base.collection do
    def foo; ...; end
  end
end
```

New form:

```ruby
def self.included base
  base.class_eval do
    def foo; ...; end
  end
end
```

`def foo` inside `base.class_eval` triggers `method_added` on the including class at top level -> registered as collection. Same applies to `Joshua.plugin :name do ... end` bodies.

### 7. Removed/changed surface

* `member`, `members`, `collection`, `collections` class methods: **removed**.
* `_api_member_*` / `_api_collection_*` aliases: **gone**.
* `@@opts` / `OPTS` keys stay the same (`:collection`, `:member`, `:before_all`, `:before_member`, `:before_collection`, `:after_*`) so docs and Postman schema keep working untouched.

## File-level work (this step)

1. **`lib/joshua/base_class.rb`**
   * Add `ref(&block)` class macro (port the lux-fw snapshot/rename algorithm).
   * Rewrite `method_added` per Section 2.
   * Remove `member`, `members`, `collection`, `collections`.
   * Keep `define`, `params`, `desc`, `detail`, `icon`, `allow`, `unsafe`, `before`, `after`, `annotation`, `plugin`, `documented`, `mount_on` (their internal use of `@method_type` continues; `ref do` sets it to `:member`, root execution leaves it nil).
   * Adjust `set_callback`: root `before`/`after` registers as `before_all`/`after_all` (already does); inside `ref do` registers as `before_member`/`after_member`.

2. **`lib/joshua/base_instance.rb`**
   * In `initialize`, set `@ref = @api.id` and `@bearer_token = @api.bearer`.
   * Rewrite `resolve_api_body` per Section 3.
   * Simplify `super!` per Section 5.

3. **`lib/doc/doc.rb` and `lib/doc/postman_schema.rb`**
   * No changes expected (they read from `OPTS[:collection]` / `OPTS[:member]`, which still get populated).
   * Smoke-test that `render_type :member` / `render_type :collection` paths work end-to-end.

4. **`api/*.rb` (demo APIs used by specs)**
   * Rewrite `application_api.rb`, `model_api.rb`, `user_api.rb`, `company_api.rb`, `board_api.rb`, `generic_api.rb`, `module.rb` in the new style. These power the spec suite.

5. **`demos/inherited-model/*.rb`**
   * Rewrite in the new style so the demo still boots and renders docs.

6. **`spec/tests/*.rb`**
   * Existing tests assert HTTP-shape behavior (`Foo.render.action(...)`) - most should pass unchanged.
   * Likely candidates needing tweaks: `define_spec.rb`, `inheritance_spec.rb`, `annotations_spec.rb` (anything that pokes at internal `_api_*` names or `method_type`).
   * Add new file `spec/tests/ref_spec.rb` covering:
     * `ref do` defines a `:show_ref` method.
     * Private helpers inside `ref do` are renamed (`:helper_ref`) and not exposed as endpoints.
     * Private helpers at root are not exposed as endpoints.
     * `@ref` and `@bearer_token` set before action runs (visible in `before do`).
     * `before do` at root fires for both collection and ref actions.
     * `before do` inside `ref do` fires only for ref actions.
     * `define :foo do ... end` inside `ref do` becomes `:foo_ref`.
     * `super` (and `super!` compat shim) works across both collection and ref methods.
   * Add new file `spec/tests/kitchen_sink_spec.rb` (or fixture API `spec/lib/kitchen_sink_api.rb` + a spec that exercises it) demonstrating **every** feature in one class:
     * `documented`, `desc`, `detail`, `icon` at class level.
     * `mount_on`.
     * `rescue_from` (named + class-based).
     * `annotation` definition + usage on a method.
     * `before do` / `after do` at root.
     * `before do` inside `ref do` (member-scoped).
     * Root collection methods via both `def name` and `define :name do ... end`.
     * `params do ... end`, `desc`, `detail` per method.
     * `unsafe` and `allow` (single + multiple verbs).
     * `define get: :foo do ... end` and `define [:get, :put] => :bar do ... end` RESTful syntax.
     * `ref do` with `def`, `define`, and a `private` helper inside it.
     * Private helpers at root (one with `private` keyword, one with a trailing `?` predicate).
     * Inheritance: a parent class with collection + ref actions + `super` / `super!` from the child.
     * Module include (`include Foo` where Foo contributes an action).
     * `plugin` definition + usage.
     * `params :custom_type do ... end` (custom Typero type).
     * Reading `@ref`, `@bearer_token`, `@api.*` inside an action.
     * Calling another action's logic via plain Ruby (helper extraction).
   * The spec asserts the full happy path of each feature and at least one error path (`error :name`, `error 404, 'x'`, params validation failure). This becomes the canonical reference example, also linked from `AI_LIB_GUIDE.md`.
   * Add new file `spec/tests/inherited_model_spec.rb` modelled on `~/dev/dux/accounting/app/api/model_api.rb`. Mirrors the real-world `ModelApi` + `generate` pattern:
     * **Base class `ExampleModelApi`** with:
       * Class macro `self.generate(name)` that dynamically defines actions - for `:create` it calls `class_eval` at root (registers a collection action); for `:show`/`:update`/`:destroy` it calls `ref do ... end` (registers a member action). Each generated action body is `define_method(name) { send("generated_#{name}") }`.
       * Root `before do` that loads `@object` from `@ref` (or builds a new one when `@ref` is nil), demonstrating both collection and ref paths sharing the same root callback.
       * Root `after do` that sets response meta.
       * Private root helpers `generated_show`, `generated_create`, `generated_update`, `generated_destroy`, plus utility helpers (`display_name`, `object_params`) - none of them reachable as endpoints.
     * **Child class `WidgetsApi < ExampleModelApi`** that:
       * Calls `generate :show`, `generate :create`, `generate :update`, `generate :destroy`.
       * Overrides `update` inside `ref do` (so it lands as `:update_ref`) with a body that does some pre-work, calls `super` (or `super!`), then mutates the response - asserts `super` reaches the generated parent `:update_ref`.
       * Adds a new ref action `def archive` that calls a private root helper from the parent (`display_name`) - asserts cross-class private helpers are reachable from member actions.
       * Overrides a collection action with `super!` - asserts collection-side `super` works through generated parent methods.
     * Spec assertions:
       * `WidgetsApi.render.show(1)` returns the generated parent body untouched.
       * `WidgetsApi.render.update(1, name: 'x')` runs child pre-work, then parent generated `update`, then child post-work, in that order.
       * `WidgetsApi.render.create(name: 'x')` runs the parent generated `create`.
       * Trying to hit `generated_show` / `display_name` as an action returns "method not found" (private helpers must not be exposed).
       * `before do` from `ExampleModelApi` runs for `WidgetsApi.render.show(1)` (i.e. `@object` is loaded by the time the action body runs).

7. **Docs (in this repo only)**
   * `README.md` and `AI_LIB_GUIDE.md`: replace `member do` / `collection do` examples with the new style.
   * `AGENTS.md`: update "Do NOT" list - drop the `super!` rule, replace with "prefer `super`". Replace the `collection { ... } / member { ... }` examples with the new DSL.

## Verification before merging `refactor` -> `master`

1. `bundle exec rspec` passes (all existing tests + new `ref_spec.rb`).
2. `bin/joshua --help` or whatever the CLI entry is still works.
3. Boot `config.ru` standalone, hit `/api`, confirm docs render and a sample action responds.
4. Boot `demos/inherited-model` similarly.
5. User signs off.

## Out of scope for Step 1

* Migration of any lux app (see `refactor-step-2.md`).
* Changing the `OPTS` schema keys.
* Deprecation/removal of `super!` (kept as compat shim).
* Adding a collection-only `before do` shortcut (not needed; document the `next if @ref` pattern instead).
