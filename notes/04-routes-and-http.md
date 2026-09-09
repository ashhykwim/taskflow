# 04 — Routes, HTTP Verbs, and What Gets Called

---

## Every route in this app

Real output of `bin/rails routes`:

| Prefix | Verb | URL | Controller#Action | Purpose |
|---|---|---|---|---|
| `root` | GET | `/` | `dashboard#index` | the dashboard |
| `tasks` | GET | `/tasks` | `tasks#index` | list all tasks |
| | POST | `/tasks` | `tasks#create` | save a new task |
| `new_task` | GET | `/tasks/new` | `tasks#new` | show the blank form |
| `edit_task` | GET | `/tasks/:id/edit` | `tasks#edit` | show the filled form |
| `task` | GET | `/tasks/:id` | `tasks#show` | display one task |
| | PATCH | `/tasks/:id` | `tasks#update` | save changes |
| | PUT | `/tasks/:id` | `tasks#update` | same, older style |
| | DELETE | `/tasks/:id` | `tasks#destroy` | delete it |
| `toggle_task` | PATCH | `/tasks/:id/toggle` | `tasks#toggle` | flip completed |

Run it yourself:

```bash
bin/rails routes
bin/rails routes -g task
```

---

## The 7 RESTful actions

`resources :tasks` generates seven routes. Learn this table.

| # | Verb | Path | Action | Renders a page? | Changes data? |
|---|---|---|---|---|---|
| 1 | GET | `/tasks` | index | yes | no |
| 2 | GET | `/tasks/new` | new | yes | no |
| 3 | POST | `/tasks` | create | no, redirects | **yes** |
| 4 | GET | `/tasks/:id` | show | yes | no |
| 5 | GET | `/tasks/:id/edit` | edit | yes | no |
| 6 | PATCH | `/tasks/:id` | update | no, redirects | **yes** |
| 7 | DELETE | `/tasks/:id` | destroy | no, redirects | **yes** |

**The pattern:** `new` shows the form, `create` saves it. `edit` shows the form,
`update` saves it. Four GETs that render pages, three that change data and redirect.

**Notice `/tasks` appears twice** — once as GET (index), once as POST (create). Same
URL, different verb, different action. That is exactly what REST means: the verb is
part of the identity of the request.

**Why does `/tasks/new` not clash with `/tasks/:id`?** Rails matches routes top to
bottom and puts `new` above `:id`. Otherwise `new` would be read as an id.

---

## The 8th route: `toggle`

```ruby
resources :tasks do
  member do
    patch :toggle
  end
end
```

**Why not one of the seven?** Because "flip this record's boolean" isn't create, read,
update or delete in the REST sense. You *could* force it through `update` by submitting
a form with `completed` set — but then a one-click button needs a full form with the
value computed in the view. A dedicated route is clearer.

**`member` vs `collection`:**

```ruby
member do
  patch :toggle        # /tasks/3/toggle   - acts on ONE record, needs an id
end

collection do
  delete :destroy_all  # /tasks/destroy_all - acts on the WHOLE set, no id
end
```

**Why PATCH and not GET?** Because it changes data. A `GET` must never modify anything
— browsers and crawlers pre-fetch GET links, which would silently toggle your tasks.
This is a genuinely good thing to say in an interview.

---

## Route helpers

Every prefix in the routes table becomes a method.

| Helper | Produces |
|---|---|
| `root_path` | `/` |
| `tasks_path` | `/tasks` |
| `new_task_path` | `/tasks/new` |
| `task_path(@task)` | `/tasks/3` |
| `edit_task_path(@task)` | `/tasks/3/edit` |
| `toggle_task_path(@task)` | `/tasks/3/toggle` |

**`_path` vs `_url`:** `_path` gives a relative path (`/tasks/3`), `_url` gives the
full thing (`http://localhost:3000/tasks/3`). Use `_path` in views and redirects; use
`_url` in emails, where a relative link is meaningless.

**Always use helpers, never hardcoded strings.** Change a route and every helper
updates automatically; every hardcoded `"/tasks"` silently breaks.

**Shorthand:** passing an object where a path is expected works:

```erb
<%= link_to "View", @task %>              <%# same as task_path(@task) %>
<%= button_to "Delete", @task, method: :delete %>
```

and in controllers:

```ruby
redirect_to @task                          # same as redirect_to task_path(@task)
```

---

## Which verb does each button send?

| UI element | Verb | Route | Action |
|---|---|---|---|
| Clicking a task title | GET | `/tasks/3` | show |
| "+ New Task" | GET | `/tasks/new` | new |
| "Create Task" submit | POST | `/tasks` | create |
| "Edit" | GET | `/tasks/3/edit` | edit |
| "Update Task" submit | PATCH | `/tasks/3` | update |
| "Complete" / "Undo" | PATCH | `/tasks/3/toggle` | toggle |
| "Delete" | DELETE | `/tasks/3` | destroy |
| "Pending" filter tab | GET | `/tasks?status=pending` | index |

---

## Why some are links and some are buttons

```erb
<%= link_to "Edit", edit_task_path(task) %>          <!-- an <a> tag -->
<%= button_to "Delete", task, method: :delete %>     <!-- a <form> -->
```

**Links are always GET.** There is no way to make an `<a>` tag send a DELETE on its
own. So anything that changes data has to be a form — which is what `button_to`
generates.

`button_to` renders:

```html
<form class="button_to" method="post" action="/tasks/3">
  <input type="hidden" name="_method" value="delete">
  <input type="hidden" name="authenticity_token" value="...">
  <input type="submit" value="Delete">
</form>
```

Because each button is its own `<form>` (a block-level element), three of them side by
side would stack vertically. That's why `app/assets/stylesheets/application.css` has:

```css
form.button_to { display: inline-block; margin: 0; }
```

---

## The confirmation dialog

```erb
<%= button_to "Delete", task,
      method: :delete,
      form: { data: { turbo_confirm: "Delete this task?" } } %>
```

`data-turbo-confirm` is read by Turbo, which pops a browser confirm dialog and only
submits if you accept.

> In older Rails this was `data: { confirm: ... }` via Rails UJS. Rails 7+ uses Turbo
> and the attribute is `turbo_confirm`. If you ever see a confirm dialog silently not
> appearing, this is usually why.

---

## Testing routes from the terminal

GET requests are easy:

```bash
curl -i http://localhost:3000/tasks
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/tasks/1
```

POST/PATCH/DELETE need a CSRF token, so you must fetch a page first and reuse its
token **from the matching form** (tokens are per-form — see file 10):

```bash
# get the form page and save cookies
curl -s -c /tmp/c.txt http://localhost:3000/tasks/new > /tmp/page.html

# pull the token out
TOKEN=$(grep -oE 'name="authenticity_token" value="[^"]+"' /tmp/page.html \
        | head -1 | sed 's/.*value="//;s/"//')

# submit
curl -s -b /tmp/c.txt -X POST http://localhost:3000/tasks \
  --data-urlencode "authenticity_token=$TOKEN" \
  --data-urlencode "task[title]=From curl"
```

**In practice, don't do this.** Use the request tests in
`test/controllers/tasks_controller_test.rb` — they handle CSRF automatically:

```bash
bin/rails test test/controllers/tasks_controller_test.rb
```

---

## HTTP status codes this app returns

| Code | Meaning | When |
|---|---|---|
| 200 | OK | any page renders successfully |
| 302 | Found (redirect) | after create, update, destroy, toggle |
| 404 | Not Found | `Task.find` raises `RecordNotFound` |
| 422 | Unprocessable Content | validation failed, or a bad CSRF token |
| 500 | Server Error | an unhandled exception |
