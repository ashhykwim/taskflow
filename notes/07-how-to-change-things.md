# 07 — How to Change Things

**This is the most important file in this folder.**

Anyone can memorise an explanation. Being able to *modify* the code while someone
watches is what proves you actually understand it. Practise recipe 1 until you can do
it in under five minutes without looking.

---

## Recipe 1 — Add a new field to Task

Example: add a `priority` field (a number, 1–5).

**Verified: these exact steps were run on this project and they work.**

### Step 1 — migration

```bash
bin/rails generate migration AddPriorityToTasks priority:integer
```

Rails reads the migration *name* and works out what you meant. `AddXToY` produces:

```ruby
class AddPriorityToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :priority, :integer
  end
end
```

Edit it to add a default:

```ruby
add_column :tasks, :priority, :integer, default: 3
```

### Step 2 — run it

```bash
bin/rails db:migrate
```

`db/schema.rb` now shows the new column. `task.priority` already works — you did not
have to declare it anywhere.

### Step 3 — allow it through strong params

`app/controllers/tasks_controller.rb`:

```ruby
def task_params
  params.require(:task).permit(:title, :description, :completed, :priority)
end
```

**Miss this step and the field will silently not save.** No error, no message — the
value is just dropped. This is the number one gotcha when adding a field, and it's a
great thing to mention out loud: it's strong params doing its job.

### Step 4 — add it to the form

`app/views/tasks/_form.html.erb`:

```erb
<div class="mb-3">
  <%= form.label :priority, class: "form-label fw-semibold" %>
  <%= form.number_field :priority, in: 1..5, class: "form-control" %>
</div>
```

### Step 5 — show it

`app/views/tasks/show.html.erb`, inside the `<dl>`:

```erb
<dt class="col-sm-3">Priority</dt>
<dd class="col-sm-9"><%= @task.priority %></dd>
```

### Step 6 — validate it (optional)

`app/models/task.rb`:

```ruby
validates :priority, numericality: { in: 1..5 }, allow_nil: true
```

### Step 7 — check it

```bash
bin/rails console
```
```ruby
t = Task.create!(title: "Test", priority: 5)
t.priority          # => 5
Task.new(title: "x", priority: 99).valid?   # => false
```

### To undo the whole thing

```bash
bin/rails db:rollback
```

Then revert the four file edits.

---

## Recipe 2 — Add a new page

Example: an "Archive" page listing only completed tasks.

### Step 1 — route

```ruby
resources :tasks do
  collection do
    get :archive          # /tasks/archive  — no id, so `collection` not `member`
  end
  member do
    patch :toggle
  end
end
```

### Step 2 — controller action

```ruby
def archive
  @tasks = Task.completed.recent
end
```

Put it **above** `private`, or Rails won't route to it.

### Step 3 — view

Create `app/views/tasks/archive.html.erb`. The filename must match the action name.

```erb
<% content_for :title, "Archive - TaskFlow" %>
<h1 class="h3 mb-4">Archive</h1>

<div class="card border-0 shadow-sm">
  <div class="list-group list-group-flush">
    <%= render @tasks %>
  </div>
</div>
```

### Step 4 — link to it

In the layout's navbar:

```erb
<li class="nav-item">
  <%= link_to "Archive", archive_tasks_path, class: "nav-link" %>
</li>
```

Check the helper name with `bin/rails routes -g archive`.

---

## Recipe 3 — Change a validation rule

`app/models/task.rb`. To require a description of at least 10 characters:

```ruby
validates :description, presence: true, length: { minimum: 10, maximum: 1000 }
```

No migration needed — validations are Ruby, not database structure.

**But:** existing rows that violate the new rule stay in the database. Validations only
run on save. `Task.first.valid?` may now return false for old records. Worth
mentioning if asked — it shows you understand when validations actually run.

---

## Recipe 4 — Add a filter to the list

The `index` action already has the pattern:

```ruby
case params[:status]
when "completed" then @tasks = @tasks.completed
when "pending"   then @tasks = @tasks.pending
end
```

To add a search box:

```ruby
def index
  @tasks = Task.recent

  case params[:status]
  when "completed" then @tasks = @tasks.completed
  when "pending"   then @tasks = @tasks.pending
  end

  if params[:q].present?
    @tasks = @tasks.where("title LIKE ?", "%#{params[:q]}%")
  end
end
```

**Note the `?` placeholder.** Never interpolate straight into the SQL string — that's
an injection hole. The `%` wildcards go in the *value*, not the query.

Then in `index.html.erb`:

```erb
<%= form_with url: tasks_path, method: :get do |form| %>
  <%= form.text_field :q, value: params[:q], placeholder: "Search titles..." %>
  <%= form.submit "Search" %>
<% end %>
```

`method: :get` so the search lands in the query string and the URL is shareable.

---

## Recipe 5 — Rename a column

Say `completed` should be `done`.

```bash
bin/rails generate migration RenameCompletedToDoneInTasks
```

```ruby
def change
  rename_column :tasks, :completed, :done
end
```

```bash
bin/rails db:migrate
```

Then update everywhere it's referenced — the model scopes, `toggle_completed!`,
`status_label`, the controller, `_form`, `_task`, `show`, the dashboard, the seeds and
the tests.

To find them all:

```bash
grep -rn "completed" app/ db/seeds.rb test/
```

**Say this if asked:** renaming a column in a live production app is a multi-step
migration — add the new column, write to both, backfill, switch reads, then drop the
old one. Doing it in one step means downtime. Knowing this distinction is a senior-level
answer.

---

## Recipe 6 — Add a second model with a relationship

The natural next step: `Project has_many :tasks`.

```bash
bin/rails generate model Project name:string description:text
bin/rails generate migration AddProjectToTasks project:references
bin/rails db:migrate
```

```ruby
# app/models/project.rb
class Project < ApplicationRecord
  has_many :tasks, dependent: :destroy
  validates :name, presence: true
end

# app/models/task.rb
class Task < ApplicationRecord
  belongs_to :project
end
```

**Which side gets `belongs_to`?** The one whose table holds the foreign key. The
`tasks` table gets `project_id`, so `Task belongs_to :project`.

**`dependent: :destroy`** — delete a project and its tasks go too. Without it you get
orphan rows pointing at a project that no longer exists.

Then nested routes:

```ruby
resources :projects do
  resources :tasks
end
```

...which gives `/projects/1/tasks/3`, and the controller uses `@project.tasks.find(...)`
instead of `Task.find(...)`.

**And at that point you'd need `includes`** on the projects index to avoid an N+1.

---

## Recipe 7 — Change the styling

Bootstrap is vendored at `app/assets/stylesheets/bootstrap.min.css` — **don't edit
that file**, it's a third-party minified library.

Put your own CSS in `app/assets/stylesheets/application.css`. It loads after Bootstrap,
so it wins:

```css
.navbar { background-color: #1a1a2e !important; }
.card   { border-radius: 12px; }
```

Bootstrap uses `!important` in places, which is why you sometimes need it too.

**Common Bootstrap classes used in this project:**

| Class | Effect |
|---|---|
| `container` | centred, max-width wrapper |
| `row` / `col-12 col-md-4` | 12-column responsive grid |
| `card` / `card-body` | white panel with a border |
| `btn btn-primary` | blue button (`btn-success`, `btn-outline-danger`, …) |
| `badge text-bg-success` | small coloured pill |
| `alert alert-success` | the flash message box |
| `d-flex gap-2` | flexbox row with spacing |
| `mb-3` / `py-4` | margin-bottom / padding-y, scale 0–5 |
| `text-body-secondary` | muted grey text |

The responsive part is `col-12 col-md-4`: full width on phones, one third from
medium screens up.

---

## Recipe 8 — Add a test

`test/models/task_test.rb`:

```ruby
test "is invalid without a title" do
  task = Task.new(title: "")
  assert_not task.valid?
  assert_includes task.errors.full_messages, "Title can't be blank"
end
```

`test/controllers/tasks_controller_test.rb`:

```ruby
test "create saves a valid task and redirects" do
  assert_difference("Task.count", 1) do
    post tasks_url, params: { task: { title: "New task" } }
  end
  assert_redirected_to task_url(Task.last)
end
```

Common assertions:

```ruby
assert            something        # is truthy
assert_not        something        # is falsy
assert_equal      expected, actual
assert_includes   collection, item
assert_response   :success         # or :redirect, :unprocessable_entity, :not_found
assert_redirected_to some_url
assert_difference("Task.count", 1) { ... }
assert_no_difference("Task.count") { ... }
assert_match      "some text", response.body
```

Run them:

```bash
bin/rails test
bin/rails test test/models/task_test.rb
```

---

## If something breaks

| Error | Cause |
|---|---|
| `Template is missing` | no `.html.erb` matching the action name |
| `undefined method 'x' for nil` | an `@variable` was never set in the controller |
| `ActionController::ParameterMissing` | strong params `require` key doesn't match the form |
| `No route matches` | check `bin/rails routes` |
| `uninitialized constant` | file name or class name doesn't match Rails' convention |
| Form submits but nothing saves | a validation failed — check `errors.full_messages`, or the field isn't in `permit` |
| Error messages don't appear | missing `status: :unprocessable_entity` |
| `NoMethodError` on a new column | you forgot `bin/rails db:migrate` |

**Two tools that solve most of it:**

```bash
tail -f log/development.log     # every request, parameter and SQL query, live
```

and dropping `debugger` on any line in a controller — reload the page and your terminal
becomes an interactive prompt at that exact moment. Type `@task`, type `params`, look
around, then `continue`.
