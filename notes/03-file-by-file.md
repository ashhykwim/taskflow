# 03 — Every File in This Project

Only the files that matter. The rest is Rails boilerplate you didn't write and
won't be asked about.

---

## The map

```
taskflow/
├── app/
│   ├── models/task.rb                      ← data + business rules
│   ├── controllers/
│   │   ├── application_controller.rb       ← parent of all controllers
│   │   ├── tasks_controller.rb             ← the 7 CRUD actions + toggle
│   │   └── dashboard_controller.rb         ← the stats page
│   ├── views/
│   │   ├── layouts/application.html.erb    ← navbar, flash, wraps every page
│   │   ├── dashboard/index.html.erb        ← stat cards + progress + recent
│   │   └── tasks/
│   │       ├── index.html.erb              ← the list + filter tabs
│   │       ├── show.html.erb               ← one task
│   │       ├── new.html.erb                ← wrapper around the form
│   │       ├── edit.html.erb               ← wrapper around the form
│   │       ├── _form.html.erb              ← PARTIAL: shared by new + edit
│   │       └── _task.html.erb              ← PARTIAL: one row in the list
│   └── assets/
│       ├── stylesheets/bootstrap.min.css   ← vendored Bootstrap
│       ├── stylesheets/application.css     ← our own overrides
│       └── javascripts/bootstrap.bundle.min.js
│
├── config/routes.rb                        ← the URL map
├── db/
│   ├── migrate/2026..._create_tasks.rb     ← creates the table
│   ├── schema.rb                           ← AUTO-GENERATED current shape
│   └── seeds.rb                            ← demo data
├── test/                                   ← 20 tests
├── Gemfile                                 ← dependencies
└── README.md
```

---

## `app/models/task.rb`

```ruby
class Task < ApplicationRecord
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }

  scope :completed, -> { where(completed: true) }
  scope :pending,   -> { where(completed: false) }
  scope :recent,    -> { order(created_at: :desc) }

  def toggle_completed!
    update(completed: !completed)
  end

  def status_label
    completed? ? "Completed" : "Pending"
  end
end
```

**`< ApplicationRecord`** — inheritance. `ApplicationRecord` inherits from
`ActiveRecord::Base`, which is where `find`, `save`, `where`, `validates` and
everything else comes from. You never wrote those; you inherited them.

**Where do `title`, `description`, `completed` come from?** They are *not* declared
anywhere in this file. On boot, Active Record reads the `tasks` table's columns and
creates getter/setter methods for each one automatically. Add a column, get a method
for free. That's a very common interview question.

**`validates`** — rules checked before every save. They run in Ruby, not the database.

**`scope`** — named, reusable, chainable queries. `Task.completed.recent` is a single
SQL query, not two. The `-> { }` is a lambda so it's evaluated when called, not when
the class loads.

**`toggle_completed!`** — the `!` is a naming convention meaning "this changes the
object". Nothing enforces it. This method is in the model rather than the controller
because deciding what "toggling" means is business logic.

**`status_label`** — a small presentation helper so views don't repeat
`task.completed? ? "Completed" : "Pending"` in four places.

**`completed?`** — you didn't write this. Active Record generates a `?` method for
every boolean column automatically.

---

## `config/routes.rb`

```ruby
Rails.application.routes.draw do
  root "dashboard#index"

  resources :tasks do
    member do
      patch :toggle
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**`root`** — what `/` maps to.

**`resources :tasks`** — one line, seven routes. See file 04.

**`member do ... end`** — adds a route that acts on **one specific record**, so the
URL includes an id: `/tasks/3/toggle`.

The alternative is `collection do ... end`, which acts on the whole set and has no
id: `/tasks/archive_all`.

**`get "up"`** — a health check endpoint that ships with Rails. Load balancers ping
it to check the app is alive. Unused here but harmless.

---

## `app/controllers/application_controller.rb`

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
end
```

Every controller inherits from this, so anything you put here applies app-wide.
`allow_browser versions: :modern` is a Rails 8 default that blocks genuinely ancient
browsers.

---

## `app/controllers/tasks_controller.rb`

The core file. Read `02-request-flow.md` alongside it.

```ruby
before_action :set_task, only: [ :show, :edit, :update, :destroy, :toggle ]
```

Runs `set_task` before those five actions. `index`, `new` and `create` are excluded —
they don't operate on an existing record, so there's no id to look up.

**Why `before_action` at all?** Without it, five actions would each repeat
`@task = Task.find(params[:id])`. DRY — Don't Repeat Yourself.

### The `index` filter

```ruby
def index
  @tasks = Task.recent

  case params[:status]
  when "completed" then @tasks = @tasks.completed
  when "pending"   then @tasks = @tasks.pending
  end
end
```

`params[:status]` comes from the query string: `/tasks?status=pending`.

This works because scopes are **chainable** — `Task.recent` returns a relation, and
`.completed` narrows it further. It's still one SQL query, and nothing runs until the
view iterates the collection.

The `case` also acts as a whitelist: any other value is ignored and you get all tasks.
You could never inject arbitrary conditions through that parameter.

### `private`

```ruby
private

def set_task
  ...
end
```

Everything below `private` is internal. This matters for security: Rails will only
route to **public** methods on a controller. If `set_task` and `task_params` were
public, they'd be reachable as web actions.

---

## `app/controllers/dashboard_controller.rb`

Only an `index` action, computing five instance variables. See file 02 for the
`.to_f` and zero-guard explanations.

**Why is this a separate controller?** Because the dashboard isn't a CRUD operation
on tasks — it's its own page with its own purpose. One controller per *resource or
page concept*, not one per model.

---

## `app/views/layouts/application.html.erb`

Wraps every page. Contains:

- `<head>` with the CSS and JS tags
- the dark navbar with Dashboard / Tasks links and a New Task button
- the flash message area
- `<%= yield %>` — where the individual page gets inserted
- the footer

```erb
<%= link_to "Dashboard", root_path,
      class: "nav-link #{'active' if current_page?(root_path)}" %>
```

`current_page?` is a Rails helper returning true if the current URL matches. Used to
highlight the active nav item.

```erb
<% if notice.present? %>
  <div class="alert alert-success ...">
    <%= notice %>
```

`notice` and `alert` are helpers reading `flash[:notice]` and `flash[:alert]`.
Flash survives exactly one redirect and is then cleared — that's its entire purpose.

**Asset tag order matters:**

```erb
<%= stylesheet_link_tag "bootstrap.min" %>
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
```

Bootstrap first, our own CSS second, so ours wins on conflicts (normal CSS cascade).

---

## `app/views/tasks/_form.html.erb` — the partial

**A partial is a reusable chunk of a view. Its filename starts with an underscore.**

`new.html.erb` and `edit.html.erb` both contain:

```erb
<%= render "form", task: @task %>
```

The underscore is dropped when rendering. `task: @task` passes the object in as a
**local variable** — inside the partial it's `task`, not `@task`.

**Why locals rather than instance variables?** A partial that only uses locals can be
rendered from anywhere. One that reaches for `@task` silently breaks the moment it's
used somewhere that variable isn't set.

**Why one form for two pages?** They're identical apart from the heading. Written
twice, they'd drift apart the moment you add a field. Written once, both pages update
together. `form_with` handles the POST-vs-PATCH difference on its own.

### Inside the form

```erb
<% if task.errors.any? %>
  <ul>
    <% task.errors.full_messages.each do |message| %>
      <li><%= message %></li>
```

`errors` is populated by `valid?`, which `save` calls internally. Empty on a fresh
form; filled after a failed save.

```erb
<%= form.text_field :title,
      class: "form-control #{'is-invalid' if task.errors[:title].any?}" %>
```

Bootstrap's `is-invalid` class turns the field red — but only if *that specific field*
has an error.

---

## `app/views/tasks/_task.html.erb` — one row

Rendered from `index.html.erb` with:

```erb
<%= render @tasks %>
```

**That one line does a lot.** Given an array of `Task` objects, Rails infers the
partial name from the class (`Task` → `tasks/_task`), renders it once per item, and
provides each as a local named `task`. It's shorthand for:

```erb
<% @tasks.each do |task| %>
  <%= render "task", task: task %>
<% end %>
```

---

## `db/migrate/20260909072134_create_tasks.rb`

```ruby
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string  :title, null: false
      t.text    :description
      t.boolean :completed, null: false, default: false
      t.timestamps
    end
  end
end
```

**The number** is a UTC timestamp. It defines the order migrations run in and
guarantees uniqueness across a team.

**`def change`** — Rails works out how to reverse this automatically (`create_table`
reverses to `drop_table`), so `db:rollback` works with no extra code.

**`t.string` vs `t.text`** — `string` is `VARCHAR(255)`, for short values. `text` is
unlimited, for long ones. Title is a string; description is text.

**`t.timestamps`** — creates `created_at` and `updated_at`, which Rails maintains
automatically on every insert and update.

**The golden rule:** never edit a migration that has already run somewhere other than
your own laptop. Write a new one instead. Editing one means your database and the file
disagree, and everyone else's database silently diverges from yours.

---

## `db/schema.rb`

**Auto-generated. Never edit by hand.** Rewritten every time you migrate.

| Migrations | schema.rb |
|---|---|
| the **history** of changes, in order | the **current state**, a snapshot |
| you write them | Rails writes it |
| many files | one file |

A new machine can run `bin/rails db:schema:load` to jump straight to the current shape
instead of replaying every migration.

---

## `Gemfile`

Your dependency list. The two lines worth explaining:

```ruby
gem "sqlite3", ">= 2.1"
gem "json", "< 3"        # <- we added this
```

`Gemfile.lock` records the **exact** version of every gem actually installed, so every
machine gets identical versions. Commit it.

---

## `test/`

```
test/models/task_test.rb                    6 tests: validations, scopes, toggle
test/controllers/tasks_controller_test.rb  11 tests: every action, both paths
test/controllers/dashboard_controller_test.rb  3 tests: counts and rendering
test/fixtures/tasks.yml                     sample data used by the tests
```

**Fixtures** are sample rows loaded into a test database before each test. This app has
two: one completed, one pending. The test database is separate from development, so
tests never touch your real data, and it's reset between tests.
