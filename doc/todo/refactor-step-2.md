# Joshua refactor - Step 2: lux app migration

## Preconditions

* Step 1 (`refactor.md`) has landed on `master` of `~/dev/dux/gems/joshua`.
* User has confirmed Joshua's specs + demo run cleanly under the new DSL.
* The `refactor` branch in `~/dev/dux/gems/joshua` has been merged.

If any of the above is false, stop and finish Step 1 first.

## Goal

Migrate every Joshua API class in every lux app from the old `collection do` / `member do` DSL to the new `ref do` + private helpers DSL, with **zero change to HTTP behavior**.

Scope: ~243 files across ~11 lux apps (see "Run plan" below).

## Migration script

Location: `~/dev/dux/gems/joshua/script/migrate_apps.rb` (or `bin/joshua-migrate`).

### Inputs

* A target directory (e.g. `~/dev/dux/sohospot.com/app`).
* Auto-detect all `*.rb` files containing `< Joshua`, `< ApplicationApi`, `< ModelApi`, or any other Joshua subclass root encountered during the walk.

### Transformations (per file)

Line-based parser (the structure is predictable enough; full Ruby AST is overkill). The script is **idempotent**: running it twice is a no-op.

1. **Unwrap `collection do ... end` / `collections do ... end`**
   * Match the block at depth-2 indent (class body). Move every line inside to the class root, preserving order.
   * Drop the `collection do` / `end` lines.
   * Dedent contents by 2 spaces.

2. **Rename `member do` / `members do` -> `ref do`**
   * In-place rename. Body untouched (it now uses `ref do` semantics).

3. **Mark existing root helpers as `private`**
   * Identify methods that were at class root **before** the refactor (i.e. helpers, not endpoints).
   * Safer approach: **reorder** so all original root helpers move to the bottom of the class, after a single `private` keyword - this avoids accidentally flipping visibility on interleaved DSL macros (`before`, `desc`, `params`, etc.).
   * Skip class methods (`def self.foo`) - they are unaffected.
   * Do not move Joshua DSL macros (`before`, `after`, `params`, `desc`, `detail`, `unsafe`, `allow`, `mount_on`, `rescue_from`, `annotation`, `documented`, `plugin`, `generate`).

4. **Handle `before do` / `after do` that lived inside `collection do`**
   * After unwrapping, those move to root and now fire for ref methods too.
   * Default: leave as-is (acceptable in all surveyed cases - body usually sets a `Site.current`-style ivar that's idempotent for member methods).
   * Print a warning per file so the developer can manually narrow scope (e.g. add `next if @ref`) if needed.

5. **Reference rename for callers**
   * No external code calls the API methods by their internal `_api_*` name (those were never public). Skip.

### Outputs

* Rewritten files in place (per repo, so each commit is scoped).
* A summary log per repo listing:
  * Files changed.
  * Files skipped (no Joshua block found).
  * Warnings (e.g. `collection do` containing a `before do`).
  * Files flagged for manual review (unusual structure: nested blocks, `eval`-built method names, modules contributing actions through `included`).

### Manual review buckets (known outliers)

From the survey done in Step 1:

* `~/dev/dux/sohospot.com/app/api/model_api.rb` (and equivalents in accounting, soho-tasks, etc.) - has the `self.generate name` macro that calls `member do` / `collection do` dynamically. Needs porting to the new DSL: at top level for `:create`, inside `ref do` for `:show`/`:update`/`:destroy`. After porting, `generated_show`/`generated_create`/etc. live as private helpers at root and are invoked from the generated wrappers.
* `~/dev/dux/accounting/app/models/invoice/invoice_api.rb` and two siblings already use `private` keyword for helpers - confirm the script doesn't double-add `private`.
* `~/dev/dux/cms-lux/app/lib/apps.rb` - check if it metaprograms API classes.
* Any file with `include SomeApiModule` where the module body calls `base.collection do` - rewrite the module to use `base.class_eval do` (still legal Ruby, registers as collection in new DSL).

## Run plan

Process repos one at a time. For each:

1. Create branch `joshua-refactor` (or similar) in the repo.
2. Run the migration script: `ruby ~/dev/dux/gems/joshua/script/migrate_apps.rb ./app`.
3. Review the summary log; hand-fix flagged outliers.
4. Run that app's test suite (or boot it and hit representative endpoints if there's no suite).
5. Commit changes per repo (do not auto-push - house rule).
6. Hand off to user for review/merge.

Order (skip the `-old` / `-fixing` mirror dirs unless explicitly requested):

1. `~/dev/dux/sohospot.com`
2. `~/dev/dux/accounting`
3. `~/dev/dux/soho-tasks`
4. `~/dev/dux/nekretnine`
5. `~/dev/dux/sleepy-shoe`
6. `~/dev/dux/bolja-pomoc`
7. `~/dev/dux/authcog.com`
8. `~/dev/dux/cms-lux`
9. `~/dev/dux/telegram`
10. `~/dev/dux/racunovodstvo`

## Verification per repo

* Test suite green (where present).
* Boot the app, hit one collection endpoint and one member endpoint per representative API class.
* Spot-check that no helper method got promoted to an endpoint by accident (`grep` for public method names that match `/api/<class>/<name>` in logs).

## Rollback

* Each repo's migration is its own branch + commit -> revert is `git reset --hard` to the parent commit before the migration commit.
* If Joshua itself needs a regression fix mid-rollout, fix it in `~/dev/dux/gems/joshua` first, then re-run the migration for the affected repo.

## Estimated work

* Migration script: ~half a day to write + dry-run review.
* Lux app migrations + test fixes: ~one day total across all repos (script does the bulk, manual cleanup on outliers).
