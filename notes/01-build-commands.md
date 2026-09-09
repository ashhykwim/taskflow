# 01 — Every Command Used to Build This Project

In order, with what each one actually did.

---

## 1. Create the application

```bash
cd ~
rails new taskflow
```

**What it does:** creates the whole folder structure, writes a `Gemfile`, runs
`bundle install`, and initialises a git repository.

**What it gave us (Rails 8 defaults):**

| Thing | What it is |
|---|---|
| SQLite | the database. One file at `storage/development.sqlite3` |
| Propshaft | serves CSS/JS from `app/assets` |
| Importmap | loads JavaScript without a build step (no webpack/npm) |
| Turbo + Stimulus | Hotwire. Makes page navigation feel faster |
| Solid Queue/Cache/Cable | background jobs, caching, websockets (unused here) |
| Puma | the web server |
| Minitest | the testing framework |

> **Key difference from your `ayush.api`:** that one was made with `rails new ... --api`,
> which sets `config.api_only = true` and removes views, layouts and helpers entirely.
> TaskFlow is full-stack, so it can render HTML pages.

---

## 2. Generate the model

```bash
cd ~/taskflow
bin/rails generate model Task title:string description:text completed:boolean
```

**Created four files:**

```
db/migrate/20260909072134_create_tasks.rb   the migration
app/models/task.rb                          the model class (empty at first)
test/models/task_test.rb                    a test stub
test/fixtures/tasks.yml                     sample test data
```

**Note the singular:** `generate model Task`, not `Tasks`. Rails convention is a
**singular model** (`Task`) mapping to a **plural table** (`tasks`). Getting this
wrong is the most common beginner mistake.

**`bin/rails` vs `rails`:** `bin/rails` uses the exact gem versions pinned in this
project's `Gemfile.lock`. Plain `rails` uses whatever is installed system-wide.
Always use `bin/rails` inside a project.

---

## 3. Edit the migration by hand

The generator produced plain columns. It was edited to add constraints:

```ruby
create_table :tasks do |t|
  t.string  :title, null: false                        # <- added null: false
  t.text    :description
  t.boolean :completed, null: false, default: false    # <- added both
  t.timestamps
end
```

**Why:** `default: false` means a new task is never `nil` for completed — without
it you'd have three states (true/false/nil) instead of two, and `completed?` on a
nil would be confusing. `null: false` is a **database-level** guarantee, separate
from the model validation.

---

## 4. Run the migration

```bash
bin/rails db:migrate
```

**What it does:** executes any migration that hasn't run yet, creating the `tasks`
table, then **regenerates `db/schema.rb`** to match.

**Related commands you should know:**

```bash
bin/rails db:migrate:status   # which migrations have run
bin/rails db:rollback         # undo the last migration
bin/rails db:seed             # load db/seeds.rb
bin/rails db:setup            # create + migrate + seed, all at once
bin/rails db:reset            # drop everything and rebuild. Development only.
```

---

## 5. Write the routes, model, controllers and views

These files were written directly rather than generated:

```
config/routes.rb
app/models/task.rb
app/controllers/tasks_controller.rb
app/controllers/dashboard_controller.rb
app/views/layouts/application.html.erb
app/views/dashboard/index.html.erb
app/views/tasks/{index,show,new,edit,_form,_task}.html.erb
```

**The generator equivalents**, if you want to recreate the skeletons yourself:

```bash
bin/rails generate controller Tasks index show new edit
bin/rails generate controller Dashboard index
```

That creates the controller file, a matching `app/views/<name>/` folder with an
empty `.erb` per action, a test file, and a helper.

> **There is also `bin/rails generate scaffold Task title:string ...`** which writes
> the model, migration, controller, all views and routes in one command. It was
> deliberately **not** used here. Scaffold code is code you didn't write, which
> means you can't defend it. Everything here was written deliberately.

---

## 6. Seed sample data

```bash
bin/rails db:seed
```

Runs `db/seeds.rb`, which wipes the tasks table and inserts 5 demo tasks
(2 completed, 3 pending). Safe to re-run any time to get back to a clean state.

---

## 7. Start the server

```bash
bin/rails server
# or on another port:
bin/rails server -p 3001
```

Boots Puma on http://localhost:3000. `Ctrl + C` stops it.

**Port 3001 was used during development** because port 3000 was occupied by
another Rails app of yours.

To find and stop whatever is holding a port:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN     # what's using port 3000
pkill -f "puma.*3001"                # stop the server on 3001
```

---

## 8. Fix the json gem conflict

```bash
# added to Gemfile:
gem "json", "< 3"

bundle install
```

**Why:** see `10-problems-we-hit.md`. Short version — the `json` 3.x gem changed
`JSON.parse`'s signature, which breaks how Rails decodes the session cookie, which
is where flash messages live. Every flash message raised an error until this pin.

---

## 9. Vendor Bootstrap locally

```bash
mkdir -p app/assets/stylesheets app/assets/javascripts

curl -o app/assets/stylesheets/bootstrap.min.css \
  https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css

curl -o app/assets/javascripts/bootstrap.bundle.min.js \
  https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js
```

Then referenced in the layout with `stylesheet_link_tag` / `javascript_include_tag`
instead of a `<link href="https://cdn...">`.

**Why not a CDN:** Brave's Shields block `cdn.jsdelivr.net`, so the page rendered
completely unstyled with no error message. Serving it locally also means the app
works with no internet.

---

## 10. Run the tests

```bash
bin/rails test                                    # everything
bin/rails test test/models/task_test.rb           # one file
bin/rails test test/controllers/tasks_controller_test.rb:30   # one test, by line
bin/rails test -b                                 # with full backtrace
```

Currently **20 tests, 60 assertions, all passing.**

---

## 11. Other commands worth knowing

```bash
bin/rails console          # interactive Ruby with your app loaded. Shortcut: bin/rails c
bin/rails routes           # list every route
bin/rails routes -g task   # filter routes
bin/rails about            # versions of everything
bin/rails db               # open a SQLite prompt
tail -f log/development.log   # watch every request and SQL query live
```

**`bin/rails console` is the single most useful one.** Any time you're unsure what
a method does, open it and try:

```ruby
Task.count
Task.first
Task.completed.count
Task.new(title: "").valid?
Task.new(title: "").errors.full_messages
```

Add `--sandbox` to roll back everything you do on exit:

```bash
bin/rails console --sandbox
```
