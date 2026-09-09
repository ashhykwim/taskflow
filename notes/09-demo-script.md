# 09 — Demo Script

The exact order to walk Aadarsh bhaiya through this. Roughly 15 minutes plus questions.

---

## Before you start

```bash
cd ~/taskflow
bin/rails db:seed        # clean demo data: 5 tasks, 2 done, 3 pending
bin/rails server
```

Open **http://localhost:3000**.

Have three things ready:
- the browser
- your editor with the project open
- a second terminal running `tail -f log/development.log`

That third one is the detail that makes you look like you know what you're doing.

---

## Part 1 — Show the working app (3 min)

Don't touch code yet. Just drive it.

1. **Dashboard** — "5 tasks, 2 completed, 3 pending, 40% done. These are four separate
   COUNT queries plus one for the recent list."
2. **Tasks** — click through. "Filter tabs are just a query parameter — watch the URL."
   Click Pending, point at `/tasks?status=pending`.
3. **Create** — click New Task, fill it, submit. Point at the green flash.
4. **Validation** — New Task again, leave the title blank, submit. "Notice it kept my
   description and told me what's wrong. That's a `render`, not a redirect — I'll show
   you why in a minute."
5. **Toggle** — mark something complete. "It came back to the same page. That's
   `redirect_back`."
6. **Delete** — delete the one you made. Confirm dialog, flash message.

---

## Part 2 — The request flow (4 min)

**This is the core of the demo.** Open `config/routes.rb` and
`app/controllers/tasks_controller.rb` side by side.

Say: *"Let me show you what happens when I click a task."*

Point at the log while you click one:

```
Started GET "/tasks/3" for 127.0.0.1
Processing by TasksController#show as HTML
  Parameters: {"id" => "3"}
  Task Load  SELECT "tasks".* FROM "tasks" WHERE "tasks"."id" = ? LIMIT ?
  Rendered tasks/show.html.erb within layouts/application
Completed 200 OK
```

Then walk it:

1. `routes.rb` — `resources :tasks` created this route. Show `bin/rails routes`.
2. `before_action :set_task` — runs first, does the `find`, sets `@task`.
3. `def show; end` — "empty, because Rails renders the matching view automatically."
4. `show.html.erb` — "`@task` is visible here **because of the `@`**. A plain local
   variable wouldn't be."
5. The layout wraps it at `<%= yield %>`.

---

## Part 3 — Create, and redirect vs render (3 min)

Open `create` in the controller.

> "Creating is actually two requests. `GET /tasks/new` builds an empty `Task.new` —
> nothing is saved yet, but the form needs an object to build itself from. Then
> `POST /tasks` does the real work.
>
> `@task.save` returns true or false. On success I **redirect** — that's the
> POST/Redirect/GET pattern, so refreshing doesn't re-submit the form. On failure I
> **render**, because `@task` still holds what they typed and the error messages. A
> redirect would throw all of that away.
>
> And `status: :unprocessable_entity` is required — since Rails 7, Turbo only replaces
> the page on a redirect or an error status. Return a plain 200 and the errors silently
> never appear. I hit that."

Then show `task_params`:

> "Strong parameters. `permit` is an allowlist. Without it, someone could add a field to
> the form in their browser and write to a column I never intended to expose — that's
> mass assignment."

---

## Part 4 — The model (2 min)

Open `app/models/task.rb`. It's short, so read it out.

Key points:
- **"`title` and `completed` aren't declared anywhere."** Active Record reads the table's
  columns at boot and creates the methods. `completed?` comes free with any boolean.
- **Validations** run in Ruby before save. Point at `null: false` in the migration too:
  "the validation gives a nice message, the database constraint is the actual guarantee."
- **Scopes** are chainable and compose into one SQL query.
- **`toggle_completed!` is in the model, not the controller** — deciding what toggling
  means is business logic. Fat model, skinny controller.

---

## Part 5 — The console (2 min)

This always lands well.

```bash
bin/rails console
```

```ruby
Task.count
Task.completed.count
Task.pending.count

t = Task.new(title: "")
t.valid?
t.errors.full_messages

Task.completed.recent.limit(2).map(&:title)
```

> "Every query prints its SQL. This is how I check what a method actually does."

---

## Part 6 — Tests (1 min)

```bash
bin/rails test
```

> "20 tests. Model tests for the validations and scopes, request tests for every
> controller action — including the failure paths, like posting a blank title and
> asserting I get a 422 with the error message."

Open `test/controllers/tasks_controller_test.rb` and read one test aloud.

---

## Part 7 — Change something live (3 min)

**The strongest part of the whole demo.** Ask: *"Want me to add a field?"*

Then do recipe 1 from `07-how-to-change-things.md` — add `priority`:

```bash
bin/rails generate migration AddPriorityToTasks priority:integer
# edit the migration, add default: 3
bin/rails db:migrate
```

Add `:priority` to `permit`, add the field to `_form.html.erb`, reload the browser.

**Deliberately forget `permit` the first time**, show that the value silently doesn't
save, then say: *"That's strong parameters doing its job — anything not on the allowlist
gets dropped."* Then add it and show it working.

That one move demonstrates more understanding than twenty minutes of explanation.

To undo afterwards: `bin/rails db:rollback`.

---

## Things to say that show depth

Drop these in naturally:

- *"Links are always GET, so anything that changes data has to be a form — that's why
  Delete is a `button_to` and not a `link_to`."*
- *"The `_method=delete` hidden field gets rewritten into a real DELETE by Rack
  middleware, because HTML forms only support GET and POST."*
- *"Flash lives in the session cookie and survives exactly one redirect."*
- *"There's no N+1 here because there are no associations — but the moment I add
  Projects, the index would need `includes`."*
- *"`toggle` is a `member` route because it acts on one record. A `collection` route
  would have no id."*

---

## If you don't know something

Say so, then show how you'd find out:

> "I'm not sure — let me check." Then `bin/rails routes`, or open the console, or
> `tail log/development.log`.

That is a better answer than guessing. Knowing how to find out is the actual skill.

---

## Two-minute pre-demo checklist

- [ ] `bin/rails db:seed` — clean data
- [ ] `bin/rails server` running, page loads, **styling appears** (hard-refresh with
      Cmd+Shift+R if not)
- [ ] `bin/rails test` — 20 green
- [ ] second terminal on `tail -f log/development.log`
- [ ] editor open on `tasks_controller.rb`
- [ ] you can trace `GET /tasks/3` end to end with no notes
