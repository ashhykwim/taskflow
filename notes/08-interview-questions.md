# 08 — Interview Questions, Answered From This Code

Every answer points at real code in this project. Answering "in `TasksController#create`
I did X because Y" is far stronger than reciting a definition.

---

## A. Rails fundamentals

**1. What is Ruby on Rails?**
A web framework written in Ruby. It's opinionated — it gives you a standard structure
(MVC), standard URL conventions (REST) and an ORM (Active Record), so you write
application logic rather than plumbing.

**2. What does MVC mean?**
Model, View, Controller. Model = data and business rules (`app/models/task.rb`).
View = what the user sees (`app/views/`). Controller = the traffic cop that takes a
request, asks the model for data, and picks a view (`app/controllers/`).

**3. What does "convention over configuration" mean?**
Rails assumes sensible defaults so you don't configure them. `TasksController#show`
automatically renders `app/views/tasks/show.html.erb` — no config anywhere. Model
`Task` automatically maps to table `tasks`. Follow the naming and it just works.

**4. Walk me through what happens when I visit /tasks/3.**
Routes matches `GET /tasks/:id` to `tasks#show` and puts `3` in `params[:id]`.
`before_action :set_task` runs `Task.find(params[:id])`, which issues
`SELECT * FROM tasks WHERE id = 3 LIMIT 1` and puts the object in `@task`.
The `show` action is empty because Rails renders the matching view automatically.
`show.html.erb` reads `@task`, the layout wraps it, HTML goes back with a 200.

**5. Model is singular but the table is plural — why?**
Rails convention. One object is a `Task`; the table holds many, so it's `tasks`.
`bin/rails generate model Task` creates exactly that.

**6. What's in the `app` folder vs `config` vs `db`?**
`app` is your code — models, views, controllers. `config` is settings, most importantly
`routes.rb`. `db` is migrations, `schema.rb` and seeds.

---

## B. Routing

**7. What does `resources :tasks` do?**
Creates seven RESTful routes in one line: index, new, create, show, edit, update,
destroy — mapping HTTP verb + path combinations to controller actions.

**8. Name the seven actions and their verbs.**
GET /tasks (index), GET /tasks/new (new), POST /tasks (create), GET /tasks/:id (show),
GET /tasks/:id/edit (edit), PATCH /tasks/:id (update), DELETE /tasks/:id (destroy).

**9. `/tasks` maps to two actions. How does Rails tell them apart?**
By HTTP verb. GET is index, POST is create. Same path, different verb, different
action — that's what REST means.

**10. You have an 8th route. Why isn't it one of the seven?**
`PATCH /tasks/:id/toggle`. Flipping a boolean isn't create/read/update/delete in the
REST sense. I added it with a `member` block because it acts on one specific record and
needs an id in the URL.

**11. `member` vs `collection`?**
`member` routes act on one record and include an id (`/tasks/3/toggle`).
`collection` routes act on the whole set and don't (`/tasks/archive`).

**12. Why is toggle a PATCH and not a GET?**
It changes data. GET must be safe — browsers and crawlers pre-fetch GET links, which
would silently toggle tasks. Anything that mutates state needs a non-GET verb.

**13. What's a route helper?**
A generated method producing a URL. `task_path(@task)` gives `/tasks/3`. Using helpers
instead of hardcoded strings means routes can change without breaking every link.

**14. `_path` vs `_url`?**
`_path` is relative (`/tasks/3`), `_url` is absolute
(`http://localhost:3000/tasks/3`). Use `_path` in views; use `_url` in emails, where a
relative link is meaningless.

**15. How do you see all routes?**
`bin/rails routes`, or `bin/rails routes -g task` to filter.

---

## C. Controllers

**16. What does a controller do?**
Receives the request, pulls what it needs from `params`, asks the model to do the work,
and decides what to render or where to redirect. It should stay thin.

**17. What is `before_action`?**
A filter that runs before the action. Mine runs `set_task` before show, edit, update,
destroy and toggle, so five actions don't each repeat `Task.find(params[:id])`. `only:`
and `except:` control which actions it applies to.

**18. `redirect_to` vs `render`? (asked constantly)**
`redirect_to` tells the browser to make a *new* request to a different URL — two round
trips, URL changes, instance variables are lost. `render` builds HTML immediately in
the *same* request — one round trip, URL unchanged, instance variables kept.
In `create` I redirect on success and render on failure.

**19. Why redirect after a successful save?**
POST/Redirect/GET. It leaves the browser on a plain GET, so refreshing doesn't
re-submit the form and create a duplicate.

**20. Why render, not redirect, when validation fails?**
Because `@task` still holds what the user typed plus the error messages. A redirect
starts a fresh request and loses all of it, so the form would come back blank with no
explanation.

**21. What is `status: :unprocessable_entity` and why is it there?**
HTTP 422. Since Rails 7, Turbo intercepts form submissions and only replaces the page
on a redirect or an error status. Return a plain 200 with the re-rendered form and Turbo
discards it silently — nothing appears to happen and no errors show.

**22. What are strong parameters?**
An allowlist for incoming form data:
`params.require(:task).permit(:title, :description, :completed)`.
`require` insists the `task` key exists; `permit` accepts only those three fields.
Anything else is dropped.

**23. What attack do they prevent?**
Mass assignment. Without an allowlist a user could add an extra field to the form in
their browser — say `admin: true` — and write to a column you never intended to expose.

**24. Why is `task_params` below `private`?**
Rails only routes to public controller methods. Keeping helpers private means they
can't be reached as web actions.

**25. Where does `params` come from?**
It's a hash Rails builds from three sources: the URL path (`:id` from
`/tasks/3`), the query string (`?status=pending`), and the request body (form fields).

**26. Why `@task` and not `task` in a controller?**
Only instance variables are copied into the view. A local variable disappears when the
method ends.

---

## D. Models and Active Record

**27. What is Active Record?**
Rails' ORM. Tables become classes, rows become objects, columns become attributes.
It generates the SQL for you.

**28. Where do `task.title` and `task.completed` come from? They're not in the model.**
Active Record reads the table's columns at boot and defines a getter and setter for
each automatically. Add a column and the method exists with no code change. Booleans
also get a `?` method, which is where `task.completed?` comes from.

**29. What's in your model and why?**
Two validations, three scopes, and two small methods. `toggle_completed!` is in the
model rather than the controller because what "toggling" means is business logic —
fat model, skinny controller.

**30. What is a migration?**
A Ruby file describing a change to the database schema. They run in timestamp order, so
anyone can rebuild the exact same database from scratch.

**31. Migration vs `schema.rb`?**
Migrations are the ordered *history* of changes, and you write them. `schema.rb` is an
auto-generated snapshot of the *current* state — never edit it by hand.

**32. Can you edit a migration that's already run?**
Only if it has never left your own machine. Once it's run anywhere else, write a new
migration instead — otherwise your database and the file disagree, and everyone else's
database silently diverges from yours.

**33. How do you undo a migration?**
`bin/rails db:rollback`, or `STEP=3` for the last three. Works because `def change`
lets Rails infer the reverse — `add_column` reverses to `remove_column`.

**34. What does `t.timestamps` give you?**
`created_at` and `updated_at`, maintained automatically by Rails.

**35. `save` vs `save!`?**
`save` returns true/false so you can branch — that's why the controller says
`if @task.save`. `save!` raises `RecordInvalid` instead, which is what you want in
seeds and scripts where failure should stop everything.

**36. Where do validations run — and what do they NOT protect against?**
In the model, in Ruby, before save. They don't protect against raw SQL,
`update_column`, or another application writing to the same database. That's why
`title` also has `null: false` in the migration — a real database constraint.

**37. What's a scope?**
A named, chainable query on the model. `scope :completed, -> { where(completed: true) }`.
Each returns a relation, so `Task.completed.recent` composes into a single SQL query.

**38. Why `-> { }` instead of `{ }`?**
It's a lambda, evaluated when called rather than when the class loads. Critical for
anything time-based — `Date.today` inside a plain block would freeze at boot time.

**39. `find` vs `find_by` vs `where`?**
`find` takes a primary key and **raises** `RecordNotFound` if missing. `find_by` takes
any attributes and returns `nil`. `where` returns a relation, possibly empty.

**40. Why does `set_task` use `find` rather than `find_by`?**
Because raising is what I want — Rails converts `RecordNotFound` into a 404
automatically, which is the correct response for a URL that doesn't exist.

**41. What is lazy loading?**
A relation doesn't hit the database until you actually need the rows. That's what
allows `.where(...).order(...).limit(...)` to chain and still be one query.

**42. What's an N+1 query and how do you fix it?**
One query for a collection, then one more per record for its association — N+1 total.
Fix with `.includes(:association)`, which eager-loads them in a second query. You spot
it in `log/development.log` as a wall of near-identical SELECTs.

**43. Do you have an N+1 in this app?**
No — `Task` has no associations, so there's nothing to lazily load. If I added
`Project has_many :tasks`, the projects index would need `includes(:tasks)`.

**44. How do you prevent SQL injection?**
Use hash conditions (`where(title: input)`) or `?` placeholders
(`where("title LIKE ?", "%#{input}%")`). Never interpolate user input directly into a
query string.

---

## E. Views

**45. `<%= %>` vs `<% %>`?**
`<%=` runs the code and prints the result. `<%` runs it silently — used for `if`,
`each` and their `end`s.

**46. How does Rails know which view to render?**
Convention: `app/views/<controller>/<action>.html.erb`. It renders it automatically
when the action ends without rendering or redirecting — that's why `def show; end` is
empty and still works.

**47. What's a layout?**
`app/views/layouts/application.html.erb` wraps every page. The individual view gets
inserted where it says `<%= yield %>`. It holds the navbar, flash area, CSS links and
footer, so they're written once instead of seven times.

**48. What's a partial?**
A reusable view fragment whose filename starts with `_`. I have two: `_form` shared by
new and edit, and `_task` for one row in the list.

**49. Why is the form a partial?**
The new and edit pages need an identical form. Written twice they'd drift apart the
moment I added a field. `form_with` works out POST vs PATCH from the object, so one
partial serves both.

**50. What does `<%= render @tasks %>` do?**
Infers the partial from the class — `Task` → `tasks/_task` — renders it once per item,
and passes each as a local named `task`.

**51. Why pass `task:` as a local instead of using `@task` in the partial?**
A partial using only locals can be rendered from anywhere. One that reaches for an
instance variable breaks silently wherever that variable isn't set.

**52. What does `form_with(model: task)` do for you?**
Four things: works out the URL and verb (POST for a new record, PATCH for a saved one),
names the fields `task[title]` so they arrive nested in params, pre-fills values from
the object, and adds the CSRF token.

**53. What is flash?**
A message stored in the session that survives exactly one redirect and is then cleared.
It exists precisely to carry a message across the redirect after a successful write.

**54. Is Rails safe from XSS by default?**
Yes — `<%= %>` HTML-escapes automatically, so a title containing `<script>` renders as
text. `html_safe` and `raw` disable that, so you never call them on user input.

---

## F. Security

**55. What is CSRF and how does Rails handle it?**
Cross-Site Request Forgery — a malicious site submitting a form to your app while your
session cookie rides along. Rails embeds a secret token in every form and verifies it
on every non-GET request. Another site can't read your token, so its request is
rejected with a 422.

**56. Why can't a Delete link be an `<a>` tag?**
Links are always GET. Anything that changes data must be a form, which is what
`button_to` generates — a POST with a hidden `_method=delete` field that
`Rack::MethodOverride` rewrites into a real DELETE.

**57. Three security features in this app?**
Strong parameters (mass assignment), the CSRF token (forged requests), and automatic
HTML escaping in ERB (XSS). All three are on by default, which is a good argument for
Rails.

---

## G. Testing

**58. How do you test this?**
`bin/rails test`. 20 tests: model tests for validations, scopes and `toggle_completed!`,
and request tests hitting every controller action including the validation-failure paths.

**59. What are fixtures?**
Sample rows in `test/fixtures/tasks.yml` loaded into a separate test database before
each test. The test database is reset between tests, so tests never touch dev data.

**60. Difference between a model test and a request test?**
A model test exercises the class directly, with no HTTP. A request test sends a real
request through routing, controller and view, and asserts on the response.

---

## H. Questions about your process (be honest)

**61. Did you build this yourself?**
Say what's true. Then pivot to what actually matters: "I can explain every line, and
I can change any part of it right now — what would you like me to add?" Then do
recipe 1 from file 07 live.

**62. What was the hardest part?**
Good honest answer: the flash-message bug. Every flash raised
`wrong number of arguments (given 2, expected 1)`. The stack trace pointed at my layout,
but the real cause was the `json` 3.x gem changing `JSON.parse`'s signature, which broke
how ActiveSupport decodes the session cookie — and flash lives in the session. Fixed by
pinning `gem "json", "< 3"`. Lesson: read the whole backtrace, not the first line.

**63. What would you add next?**
User accounts with Rails 8's built-in auth generator, so each person sees only their own
tasks. Then Projects, with `has_many :tasks` — which introduces associations and the
N+1 problem.

**64. What would you do differently?**
Use an enum instead of a boolean. `completed` only supports two states; a real task
manager wants todo / in-progress / done, which is `enum :status, { todo: 0, doing: 1,
done: 2 }`. Boolean was the right call for this scope, but it's the first thing that
would need to change.

**65. Why SQLite and not PostgreSQL?**
Zero setup, and Rails 8 made it genuinely production-capable for small apps. For heavy
concurrent writes I'd switch to PostgreSQL — one line in `config/database.yml` plus a
gem, because Active Record abstracts the difference.
