# TaskFlow

A simple task management website built with Ruby on Rails 8, using server-rendered
ERB views and Bootstrap 5. No API layer, no JavaScript framework.

Built as a reference/portfolio project, deliberately kept small and conventional.

## Requirements

- Ruby 3.4.10
- Rails 8.1.3.1
- SQLite (bundled with macOS)

## Getting started

```bash
cd ~/taskflow
bin/rails db:setup     # create the database, run migrations, load seeds
bin/rails server
```

Then open http://localhost:3000

If port 3000 is busy, run `bin/rails server -p 3001` and use
http://localhost:3001 instead.

## Features

**Dashboard** (`/`)
- Total, completed and pending task counts
- Overall completion percentage with a progress bar
- The five most recent tasks

**Tasks** (`/tasks`)
- List all tasks, filter by All / Pending / Completed
- Create, view, edit and delete a task
- Mark a task complete or move it back to pending
- Flash messages on every successful action
- Inline error messages when validation fails

## Data model

One table. A task has:

| Column | Type | Notes |
|---|---|---|
| `title` | string | required, max 100 characters |
| `description` | text | optional, max 1000 characters |
| `completed` | boolean | defaults to `false` |
| `created_at` / `updated_at` | datetime | maintained by Rails |

## Routes

```
GET    /                    dashboard#index
GET    /tasks               tasks#index
POST   /tasks               tasks#create
GET    /tasks/new           tasks#new
GET    /tasks/:id           tasks#show
GET    /tasks/:id/edit      tasks#edit
PATCH  /tasks/:id           tasks#update
DELETE /tasks/:id           tasks#destroy
PATCH  /tasks/:id/toggle    tasks#toggle     <- the only non-RESTful route
```

`resources :tasks` provides the seven standard routes. `toggle` is added as a
`member` route because "flip this one record's boolean" doesn't map cleanly onto
any of the seven.

## Important files

```
app/models/task.rb                        validations, scopes, toggle_completed!
app/controllers/tasks_controller.rb       the 7 CRUD actions + toggle
app/controllers/dashboard_controller.rb   the dashboard counts
config/routes.rb                          the URL map
db/migrate/*_create_tasks.rb              the tasks table
db/seeds.rb                               sample data

app/views/layouts/application.html.erb    navbar, flash messages, Bootstrap
app/views/dashboard/index.html.erb        stat cards + progress + recent list
app/views/tasks/index.html.erb            list + filter tabs
app/views/tasks/show.html.erb             single task + action buttons
app/views/tasks/_form.html.erb            shared by new and edit
app/views/tasks/_task.html.erb            one row in the task list
app/views/tasks/new.html.erb
app/views/tasks/edit.html.erb
```

## Tests

```bash
bin/rails test
```

20 tests covering model validations, scopes, the toggle behaviour, and every
controller action including the validation-failure paths.

## Notes

- `gem "json", "< 3"` is pinned in the Gemfile. The `json` 3.x release changed
  `JSON.parse`'s signature, which breaks ActiveSupport's session cookie decoding
  on Rails 8.1 and makes every flash message raise an error.
- Bootstrap 5.3.3 is vendored locally in `app/assets/stylesheets/bootstrap.min.css`
  and `app/assets/javascripts/bootstrap.bundle.min.js` rather than loaded from a CDN.
  Browser shields/ad-blockers (Brave in particular) block `cdn.jsdelivr.net`, which
  silently leaves the page completely unstyled. Serving it locally also means the app
  works with no internet connection. There is still no asset build step.
