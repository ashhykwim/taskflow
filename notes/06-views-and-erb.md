# 06 — Views, ERB, Layouts and Partials

---

## ERB — Embedded Ruby

HTML files with Ruby inside. **Two tags, and the difference is one `=` sign.**

```erb
<%= something %>    runs it AND prints the result into the page
<%  something %>    runs it and prints NOTHING
<%# a comment %>    ignored entirely
```

Use `<%=` for values. Use `<%` for logic — `if`, `each`, and their `end`s.

```erb
<h1><%= @task.title %></h1>

<% if @task.completed? %>
  <span class="badge">Done</span>
<% end %>

<% @tasks.each do |task| %>
  <li><%= task.title %></li>
<% end %>
```

Note that every `end` needs its own `<% %>` tag. Forgetting one is the most common
ERB error, and the message you get is usually confusing.

---

## How Rails picks a view

**Convention: `app/views/<controller_name>/<action_name>.html.erb`**

| Request | Controller | View rendered |
|---|---|---|
| `GET /tasks` | `tasks#index` | `app/views/tasks/index.html.erb` |
| `GET /tasks/3` | `tasks#show` | `app/views/tasks/show.html.erb` |
| `GET /` | `dashboard#index` | `app/views/dashboard/index.html.erb` |

You never write `render :show` in the `show` action. Rails does it for you when the
action ends without rendering or redirecting. That's why `def show; end` is empty and
still works.

You only render explicitly when you want a *different* view than the action name:

```ruby
def create
  ...
  render :new, status: :unprocessable_entity   # in `create`, render the `new` view
end
```

**`Template is missing` error** means Rails looked for a view matching the action and
didn't find one.

---

## Instance variables are the bridge

```ruby
def show
  @task = Task.find(params[:id])   # with @
  task  = Task.find(params[:id])   # without @ — INVISIBLE to the view
end
```

Only `@variables` are copied into the view context. This is the single most common
"why is my view blank" cause.

---

## The layout

`app/views/layouts/application.html.erb` wraps **every** page.

```erb
<body>
  <nav>...navbar...</nav>
  <main>
    ...flash messages...
    <%= yield %>          <%# the individual page gets inserted HERE %>
  </main>
  <footer>...</footer>
</body>
```

`yield` is the same Ruby keyword from blocks — "insert what was handed to me here".

**Why have a layout?** The navbar, CSS links and footer are identical on every page.
Without a layout you'd repeat them in all seven views and have to edit seven files to
change the navbar.

### `content_for` — pages contributing to the layout

Each page sets its own title:

```erb
<% content_for :title, "New Task - TaskFlow" %>
```

The layout reads it:

```erb
<title><%= content_for(:title) || "TaskFlow" %></title>
```

The `|| "TaskFlow"` is the fallback for pages that don't set one.

---

## Partials

**A partial is a reusable piece of a view. Its filename starts with `_`.**

This project has two:

| File | Purpose | Rendered from |
|---|---|---|
| `_form.html.erb` | the task form | `new.html.erb` and `edit.html.erb` |
| `_task.html.erb` | one row in the list | `index.html.erb` |

### Rendering with an explicit local

```erb
<%= render "form", task: @task %>
```

- the leading underscore is **dropped** when rendering
- `task: @task` passes it in as a **local variable** — inside the partial it's `task`,
  not `@task`

**Why locals rather than instance variables?** A partial using only locals can be
rendered from anywhere. One that reaches for `@task` breaks silently the moment it's
used somewhere that variable isn't set.

### Rendering a collection

```erb
<%= render @tasks %>
```

Given an array of `Task` objects, Rails:
1. infers the partial from the class — `Task` → `tasks/_task`
2. renders it once per item
3. passes each one as a local named `task`

Shorthand for:

```erb
<% @tasks.each do |task| %>
  <%= render "task", task: task %>
<% end %>
```

---

## Forms

```erb
<%= form_with(model: task) do |form| %>
  <%= form.label :title %>
  <%= form.text_field :title %>
  <%= form.text_area :description, rows: 5 %>
  <%= form.check_box :completed %>
  <%= form.submit %>
<% end %>
```

**`form_with(model: task)` does four things automatically:**

1. **Sets the URL and verb** — new record → `POST /tasks`; saved record →
   `PATCH /tasks/3`. This is why one partial serves both pages.
2. **Names the fields** `task[title]`, `task[description]` — which is why they arrive
   nested as `params[:task][:title]`, and why strong params says
   `params.require(:task)`.
3. **Pre-fills the values** from the object, so the edit form opens filled in.
4. **Adds the CSRF token** as a hidden field.

### Field helpers

```erb
<%= form.text_field :title %>
<%= form.text_area :description, rows: 5 %>
<%= form.check_box :completed %>
<%= form.date_field :due_on %>
<%= form.number_field :priority %>
<%= form.select :status, ["todo", "doing", "done"] %>
<%= form.submit "Save" %>
```

### Rendering errors

```erb
<% if task.errors.any? %>
  <div class="alert alert-danger">
    <h2><%= pluralize(task.errors.count, "error") %> stopped this from saving:</h2>
    <ul>
      <% task.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

`errors` is empty on a fresh form and populated after a failed `save`. This block only
appears when there's something to show.

Per-field highlighting:

```erb
<%= form.text_field :title,
      class: "form-control #{'is-invalid' if task.errors[:title].any?}" %>
```

---

## Flash messages

Set in the controller:

```ruby
redirect_to @task, notice: "Task was created successfully."
redirect_to tasks_path, alert: "Something went wrong."
```

Displayed in the layout:

```erb
<% if notice.present? %>
  <div class="alert alert-success"><%= notice %></div>
<% end %>
```

**Flash survives exactly one redirect, then clears itself.** That's its entire purpose
— it exists to carry a message across the redirect that follows a successful write.

It's stored in the **session cookie**, which is why the `json` gem bug broke it — see
file 10.

`notice` and `alert` are the two built-in types. `flash[:anything]` works too, but then
you must read it as `flash[:anything]` rather than a bare helper.

---

## View helpers used in this project

```erb
<%= link_to "Edit", edit_task_path(task) %>
<%= button_to "Delete", task, method: :delete %>
<%= pluralize(@tasks.count, "task") %>          <%# "1 task" / "5 tasks" %>
<%= truncate(task.description, length: 120) %>
<%= task.created_at.strftime("%d %b %Y") %>
<%= current_page?(root_path) %>                 <%# true/false, for nav highlighting %>
```

### Building CSS classes conditionally

```erb
class="nav-link <%= 'active' if current_page?(root_path) %>"
```

or inside a helper's class option, using interpolation:

```erb
<%= link_to "Tasks", tasks_path,
      class: "nav-link #{'active' if controller_name == 'tasks'}" %>
```

---

## HTML escaping — a security point worth making

`<%= %>` **escapes HTML automatically.** If a task title is
`<script>alert('hacked')</script>`, it renders as visible text, not as a running
script. That's XSS protection, on by default.

`html_safe` and `raw` switch it off:

```erb
<%= link_to "&larr; Back".html_safe, tasks_path %>
```

Used here only for the `←` arrow character, which is a fixed string we wrote
ourselves. **Never call `html_safe` on user input** — that's exactly how XSS
vulnerabilities get introduced.

---

## Assets

```erb
<%= stylesheet_link_tag "bootstrap.min" %>
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
<%= javascript_include_tag "bootstrap.bundle.min" %>
```

Served by **Propshaft** from `app/assets/`. It adds a content hash to each filename
(`bootstrap.min-474821e1.css`) so browsers cache aggressively but pick up changes
instantly — the filename changes when the content does.

**Order matters:** Bootstrap first, `application.css` second, so our overrides win by
normal CSS cascade.

> **Careful:** `stylesheet_link_tag :app` (the Rails 8 default) includes *every*
> stylesheet in the folder. That double-loaded Bootstrap here, so it was changed to
> name `"application"` explicitly.
