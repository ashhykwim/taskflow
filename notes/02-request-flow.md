# 02 — How a Request Actually Flows Through This App

If you learn one file in this folder properly, make it this one. "Walk me through
what happens when I click X" is the most common question you will be asked.

---

## The short version

```
Browser  ->  Routes  ->  Controller  ->  Model  ->  Database
                              |
                              v
                            View  ->  Layout  ->  HTML back to browser
```

Say it as: **"Route matches the URL, controller handles it, model gets the data,
view renders it, layout wraps it."**

---

## Traced example 1: viewing one task

You click a task title. The browser sends `GET /tasks/3`.

### Step 1 — `config/routes.rb`

```ruby
resources :tasks
```

Rails looks down its route table for a `GET` matching `/tasks/:id`, finds
`tasks#show`, and captures `3` into `params[:id]`.

### Step 2 — `app/controllers/tasks_controller.rb`

```ruby
before_action :set_task, only: [ :show, :edit, :update, :destroy, :toggle ]
```

`before_action` runs first. Because `show` is in that list, `set_task` runs:

```ruby
def set_task
  @task = Task.find(params[:id])
end
```

`params[:id]` is the string `"3"`. Rails converts it. If no task with id 3 exists,
`find` raises `ActiveRecord::RecordNotFound`, which Rails turns into a 404 page.

Then the actual action runs:

```ruby
def show
end
```

It's empty — and that's correct. `@task` is already set, and Rails automatically
renders the view matching the action name.

### Step 3 — the model

`Task.find(3)` produces this SQL:

```sql
SELECT "tasks".* FROM "tasks" WHERE "tasks"."id" = 3 LIMIT 1;
```

The returned row becomes a `Task` object in `@task`.

### Step 4 — `app/views/tasks/show.html.erb`

Rails renders the view whose folder matches the controller (`tasks`) and whose
filename matches the action (`show`).

```erb
<h1 class="h3 mb-0"><%= @task.title %></h1>
```

**`@task` is visible here only because it has an `@`.** A plain `task = ...` in the
controller would be a local variable and invisible to the view. This is the whole
reason Rails controllers use instance variables.

### Step 5 — `app/views/layouts/application.html.erb`

The rendered view is inserted where the layout says `<%= yield %>`. The layout
supplies the `<html>`, `<head>`, the navbar and the flash area.

### Step 6 — response

Complete HTML goes back with status 200.

**Watch it happen for real:**

```bash
tail -f log/development.log
```

---

## Traced example 2: creating a task (two requests, not one)

This is the part people get wrong. Creating a record involves **two** round trips.

### Request 1 — get the form

`GET /tasks/new` → `tasks#new`

```ruby
def new
  @task = Task.new
end
```

`Task.new` builds an **unsaved, empty** Task in memory. No database write happens.

Why build it at all? Because `app/views/tasks/_form.html.erb` starts with:

```erb
<%= form_with(model: task) do |form| %>
```

`form_with` inspects the object to decide the form's `action` and method. A new
record means `POST /tasks`; a saved record means `PATCH /tasks/:id`. Same partial,
both jobs. Without an object it has nothing to inspect.

### Request 2 — submit the form

`POST /tasks` → `tasks#create`

`params` arrives looking like:

```ruby
{
  "authenticity_token" => "...",
  "task" => {
    "title" => "Buy milk",
    "description" => "From the shop",
    "completed" => "0"
  },
  "controller" => "tasks",
  "action" => "create"
}
```

Note the form fields are **nested under `task`** — that's `form_with(model: task)`
naming them `task[title]`, `task[description]` etc.

```ruby
def create
  @task = Task.new(task_params)

  if @task.save
    redirect_to @task, notice: "Task was created successfully."
  else
    render :new, status: :unprocessable_entity
  end
end
```

`task_params` is the strong-parameters filter:

```ruby
def task_params
  params.require(:task).permit(:title, :description, :completed)
end
```

`@task.save` runs the validations. It returns `true` or `false` — it does not raise.

**Success path:** `redirect_to @task` sends a `302` with `Location: /tasks/3`.
The browser then makes a **third** request, `GET /tasks/3`, which is traced above.
The `notice:` is stashed in the session cookie and displayed once, then cleared.

**Failure path:** `render :new` builds the new-task page **immediately, in this same
request**. Because it's the same request, `@task` still holds what the user typed
*and* the error messages, so the form comes back filled in with errors shown.

### Why redirect on success but render on failure?

Redirecting after a successful write is the **POST/Redirect/GET** pattern. It means
the browser's final URL is a plain `GET`, so refreshing the page doesn't re-submit
the form and create a duplicate.

Rendering on failure keeps the user's typed input. A redirect would start a fresh
request and lose everything they wrote.

### Why `status: :unprocessable_entity`?

That's HTTP **422**. Since Rails 7, Turbo intercepts form submissions. It only
replaces the page content when the response is either a redirect or an error
status. Return a plain 200 with the re-rendered form and Turbo silently discards
it — the user sees nothing happen and no error messages appear.

---

## Traced example 3: toggling a task complete

You click "Complete". This is the only non-standard route in the app.

`PATCH /tasks/3/toggle` → `tasks#toggle`

```ruby
def toggle
  @task.toggle_completed!
  redirect_back fallback_location: tasks_path,
                notice: "Task marked as #{@task.status_label.downcase}."
end
```

`toggle_completed!` lives on the **model**, not the controller:

```ruby
def toggle_completed!
  update(completed: !completed)
end
```

That's deliberate — "what it means to toggle" is business logic, and business logic
belongs in the model. The controller only decides where to send the user next.
This is the "fat model, skinny controller" principle.

`redirect_back` sends the user to the page they came from, using the HTTP `Referer`
header. `fallback_location:` is required in case there's no referer (someone typed
the URL directly, or the browser stripped the header).

**Why this matters:** the same Complete button works from both the tasks list and a
task's own page, and returns you to whichever one you were on.

---

## Where does `_method=delete` come from?

HTML forms can only do `GET` and `POST`. There is no such thing as an HTML form
that natively sends `PATCH` or `DELETE`.

Rails works around this. `button_to "Delete", @task, method: :delete` renders:

```html
<form method="post" action="/tasks/3">
  <input type="hidden" name="_method" value="delete">
  <input type="hidden" name="authenticity_token" value="...">
  <input type="submit" value="Delete">
</form>
```

The request goes out as a real `POST`. Then the `Rack::MethodOverride` middleware
sees `_method=delete` and rewrites it to `DELETE` before it reaches your router.
By the time your controller sees it, it's a genuine `DELETE`.

**You can see this in the log:**

```
Started DELETE "/tasks/3" for 127.0.0.1
Processing by TasksController#destroy as HTML
```

---

## What is the authenticity_token?

CSRF protection — Cross-Site Request Forgery.

Without it, a malicious site could contain a hidden form pointing at your app.
If you were logged in, your browser would happily send your session cookie along,
and the action would succeed.

Rails puts a secret token in every form and checks it on every non-GET request.
Another site can't read your token, so its forged request is rejected with a 422.

**A detail worth knowing:** this app has `per_form_csrf_tokens` enabled (a Rails
default). Each form's token is bound to **that form's action URL and HTTP method**.
Two forms on the same page get different tokens, and they are not interchangeable.
This caused a real bug during testing — see `10-problems-we-hit.md`.

---

## The dashboard flow

`GET /` → `dashboard#index`

```ruby
def index
  @total_count     = Task.count
  @completed_count = Task.completed.count
  @pending_count   = Task.pending.count
  @recent_tasks    = Task.recent.limit(5)

  @completion_percentage =
    @total_count.zero? ? 0 : (@completed_count.to_f / @total_count * 100).round
end
```

Four separate SQL queries:

```sql
SELECT COUNT(*) FROM tasks;
SELECT COUNT(*) FROM tasks WHERE completed = 1;
SELECT COUNT(*) FROM tasks WHERE completed = 0;
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 5;
```

**Two things to be able to explain here:**

1. **`.to_f`** — in Ruby, `2 / 5` is `0`, because dividing two integers throws away
   the remainder. `2.to_f / 5` is `0.4`. Without `.to_f` every percentage would
   round to 0 or 100.

2. **The `@total_count.zero?` guard** — with no tasks, the division would be
   `0 / 0`, which raises `ZeroDivisionError` for integers and gives `NaN` for
   floats. The guard returns 0 instead.
