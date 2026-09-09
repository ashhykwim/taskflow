# 05 — Database, Active Record, and the Model

---

## What Active Record is

Rails' **ORM** — Object-Relational Mapper.

| Database | Ruby |
|---|---|
| table `tasks` | class `Task` |
| one row | one `Task` object |
| column `title` | method `task.title` |

You write Ruby; Active Record writes the SQL. Every method below is shown with the
SQL it produces — if you can name the SQL, you understand the method.

---

## The schema

`db/schema.rb`:

```ruby
create_table "tasks", force: :cascade do |t|
  t.boolean  "completed",   default: false, null: false
  t.datetime "created_at",  null: false
  t.text     "description"
  t.string   "title",       null: false
  t.datetime "updated_at",  null: false
end
```

Plus an `id` column Rails adds automatically as the primary key.

**Where do `task.title` and `task.completed` come from?** Nowhere in your code. On
boot, Active Record queries the table for its columns and defines a getter and setter
for each. Add a column, get methods for free. Very common interview question.

Booleans also get a `?` method: `task.completed?`.

---

## The database itself

SQLite. One file:

```
storage/development.sqlite3     your dev data
storage/test.sqlite3            wiped between test runs
```

**Why SQLite and not PostgreSQL?** It's zero-setup — no server to install or run —
and Rails 8 made it genuinely production-capable for small apps. For a bigger app with
many concurrent writers you'd switch to PostgreSQL, and the change is one line in
`config/database.yml` plus a gem, because Active Record abstracts the difference.

Open a SQL prompt directly:

```bash
bin/rails db
sqlite> .schema tasks
sqlite> SELECT * FROM tasks;
sqlite> .quit
```

---

## Validations

```ruby
validates :title, presence: true, length: { maximum: 100 }
validates :description, length: { maximum: 1000 }
```

Run automatically on `save`, `create` and `update`.

```ruby
t = Task.new(title: "")
t.valid?                 # => false   (runs the validations)
t.errors.full_messages   # => ["Title can't be blank"]
t.save                   # => false   (returns false, does NOT raise)
t.save!                  # raises ActiveRecord::RecordInvalid
```

**`save` vs `save!`** — `save` returns true/false so you can branch on it, which is
exactly why the controller says `if @task.save`. `save!` raises instead, which is what
you want in seeds and scripts where a failure should stop everything loudly. Same for
`create`/`create!` and `update`/`update!`.

### Validations are NOT database constraints

A validation is Ruby, enforced by Rails. Raw SQL, `update_column`, or another
application writing to the same database all bypass it completely.

That's why `title` has **both**:

```ruby
validates :title, presence: true      # nice error message for the user
t.string :title, null: false          # actual guarantee, in the database
```

Being able to explain that distinction marks you out from someone who's only followed
a tutorial.

### Other validations you should recognise

```ruby
validates :email,    uniqueness: true
validates :email,    format: { with: URI::MailTo::EMAIL_REGEXP }
validates :priority, numericality: { greater_than: 0 }
validates :status,   inclusion: { in: %w[todo doing done] }
validates :title,    presence: { message: "please give it a name" }
```

---

## Scopes

```ruby
scope :completed, -> { where(completed: true) }
scope :pending,   -> { where(completed: false) }
scope :recent,    -> { order(created_at: :desc) }
```

```ruby
Task.completed          # SELECT * FROM tasks WHERE completed = 1
Task.pending.count      # SELECT COUNT(*) FROM tasks WHERE completed = 0
Task.completed.recent   # WHERE completed = 1 ORDER BY created_at DESC
```

**Chainable, because each returns a relation, and still one SQL query.** That's the
whole point — `Task.completed.recent.limit(5)` hits the database once.

**Why `-> { }` and not just `{ }`?** It's a **lambda** — stored and evaluated when
called, not when the class is loaded. Irrelevant for `where(completed: true)`, but
critical for anything time-based: `-> { where("due_on < ?", Date.today) }` would
freeze the date at boot time if it weren't a lambda.

**Scope vs class method** — these are equivalent:

```ruby
scope :completed, -> { where(completed: true) }

def self.completed
  where(completed: true)
end
```

Use a scope for one-liners, a class method when there's real logic. One catch: a scope
always returns a relation, while a class method can accidentally return `nil` and break
a chain.

---

## Querying — Rails and the SQL it generates

```ruby
Task.all                          # SELECT * FROM tasks
Task.count                        # SELECT COUNT(*) FROM tasks
Task.first                        # SELECT * FROM tasks ORDER BY id LIMIT 1
Task.find(3)                      # WHERE id = 3 LIMIT 1     -> RAISES if missing
Task.find_by(title: "Ship it")    # WHERE title = ... LIMIT 1 -> returns nil
Task.where(completed: true)       # WHERE completed = 1
Task.where.not(completed: true)   # WHERE completed != 1
Task.order(created_at: :desc)     # ORDER BY created_at DESC
Task.limit(5)                     # LIMIT 5
Task.pluck(:title)                # SELECT title  -> plain strings, no objects
Task.group(:completed).count      # GROUP BY completed -> {false=>3, true=>2}
Task.exists?(3)
```

### `find` vs `find_by` vs `where`

| Method | Takes | Returns | If nothing matches |
|---|---|---|---|
| `find(3)` | primary key | one object | **raises** `RecordNotFound` |
| `find_by(x: 1)` | any attributes | one object | returns `nil` |
| `where(x: 1)` | any attributes | a relation | empty relation |

`find` raising is *useful* in a controller — Rails converts `RecordNotFound` into a
404 page automatically. That's why `set_task` uses `find`.

### Relations are lazy

```ruby
tasks = Task.where(completed: true)   # no query yet
tasks = tasks.order(:created_at)      # still nothing
tasks.each { |t| puts t.title }       # NOW it runs, once
```

Nothing hits the database until the results are actually needed. That's what makes
chaining possible.

### SQL injection

```ruby
Task.where("title = ?", user_input)       # SAFE — the ? is escaped
Task.where("title = '#{user_input}'")     # INJECTION. Never do this.
Task.where(title: user_input)             # SAFE — hash form escapes automatically
```

Same rule you already follow writing raw SQL at work.

---

## The console — your most useful tool

```bash
bin/rails console          # or bin/rails c
bin/rails console --sandbox   # rolls everything back when you exit
```

Things to try, and to demo:

```ruby
Task.count
Task.first
Task.completed.count
Task.pending.count

t = Task.create!(title: "From the console")
t.completed?                # => false
t.toggle_completed!
t.completed?                # => true
t.status_label              # => "Completed"

bad = Task.new(title: "")
bad.valid?                  # => false
bad.errors.full_messages    # => ["Title can't be blank"]

Task.new(title: "x" * 101).valid?   # => false, too long

t.destroy
exit
```

**The console prints the SQL for every query.** That's the fastest way to see what a
method actually does.

---

## `created_at` and `updated_at`

From `t.timestamps` in the migration. Rails maintains them automatically — sets both
on insert, updates `updated_at` on every save. You never assign them yourself.

Formatted for display with:

```erb
<%= task.created_at.strftime("%d %b %Y") %>       <%# 09 Sep 2026 %>
```

---

## N+1 queries — ask-me-this material

Not a problem in *this* app, because `Task` has no associations. But you will be asked.

**The problem:** a loop that touches an association fires one query per row.

```erb
<% @projects.each do |project| %>
  <%= project.user.email %>     <%# one SELECT per project! %>
<% end %>
```

20 projects = 21 queries. Fine on your laptop, fatal in production.

**The fix:**

```ruby
@projects = Project.includes(:user)     # 2 queries total, regardless of count
```

**How to spot one:** `tail -f log/development.log` and look for a wall of near-identical
SELECTs differing only by id.

**Say this if asked about it here:** "TaskFlow has a single model with no associations,
so there's no N+1 risk. The moment I added Projects with `has_many :tasks`, the index
page would need `includes(:tasks)`."
