# 10 — Real Problems Hit While Building This

Three genuine bugs. Being able to tell these stories is worth more than any memorised
definition — it shows you can debug, not just follow a tutorial.

---

## Problem 1 — Every flash message crashed

### Symptom

```
ActionView::Template::Error: wrong number of arguments (given 2, expected 1)
    app/views/layouts/application.html.erb:51
```

Line 51 was:

```erb
<% if notice.present? %>
```

Two tests failed. Both were the ones that followed a redirect and rendered a flash.

### The wrong conclusion

The error points at the layout, so the obvious reading is "`notice` is broken". But
`notice` takes no arguments, and `present?` takes none either. Nothing on that line
could be called with two arguments.

### Finding the real cause

Run the failing test with a full backtrace:

```bash
bin/rails test test/controllers/tasks_controller_test.rb:30 -b
```

The top frame wasn't the layout at all:

```
json-3.0.2/lib/json/common.rb:296:in 'parse'
activesupport/lib/active_support/json/decoding.rb:25:in 'decode'
activesupport/lib/active_support/messages/metadata.rb:129
actionpack/lib/action_dispatch/middleware/cookies.rb:689
actionpack/lib/action_dispatch/middleware/session/cookie_store.rb:121
```

### The actual cause

The `json` gem version 3.0.2 changed `JSON.parse`'s method signature. ActiveSupport
calls it with two arguments, which is no longer valid.

The chain: **flash is stored in the session → the session is stored in an encrypted
cookie → decrypting that cookie decodes JSON → JSON.parse raises.** So reading `notice`
triggered a cookie decode that blew up, and the error surfaced at the line that
happened to touch it first.

### The fix

```ruby
# Gemfile
gem "json", "< 3"
```

```bash
bundle install    # Using json 2.21.2 (was 3.0.2)
```

All 20 tests passed immediately after.

### The lesson

**Read the whole backtrace, not the first line.** The frame Rails shows you is where
the error *surfaced*, not where it *originated*. `-b` on a test run, or scrolling past
the app frames in `log/development.log`, is how you find the real one.

> Your `ayush.api` Gemfile already has this same pin, so you'd have hit it there too.

---

## Problem 2 — The whole site rendered with no styling

### Symptom

Every page loaded as raw HTML — Times New Roman, blue underlined links, no layout.

But: all pages returned HTTP 200, all 20 tests passed, and the HTML source was correct,
including the Bootstrap `<link>` tag.

### Diagnosis

Check whether the machine can reach the CDN:

```bash
curl -o /dev/null -w "%{http_code}\n" \
  https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css
# 200
```

The machine could. The browser couldn't. **Brave Shields blocks
`cdn.jsdelivr.net`** — the request never left the browser, and nothing was logged
anywhere, because a blocked stylesheet fails silently.

### The fix

Stop depending on a CDN. Download Bootstrap into the app:

```bash
curl -o app/assets/stylesheets/bootstrap.min.css \
  https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css
curl -o app/assets/javascripts/bootstrap.bundle.min.js \
  https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js
```

and reference them locally:

```erb
<%= stylesheet_link_tag "bootstrap.min" %>
<%= javascript_include_tag "bootstrap.bundle.min" %>
```

Side benefit: the app now works with no internet connection.

### A second bug this exposed

The rendered page had **two** Bootstrap `<link>` tags. Cause:

```erb
<%= stylesheet_link_tag :app %>
```

In Rails 8 with Propshaft, `:app` includes **every** stylesheet in
`app/assets/stylesheets` — which now included Bootstrap. Fixed by naming the file
explicitly:

```erb
<%= stylesheet_link_tag "bootstrap.min" %>
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
```

Order matters: Bootstrap first, our overrides second, so ours win.

### The lesson

**HTTP 200 is not visual proof.** Status codes and passing tests said the app was fine;
it looked broken. Anything visual has to be checked by actually looking at it — in a
browser, or with a headless screenshot:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --window-size=1400,1000 \
  --screenshot=out.png http://localhost:3000/
```

---

## Problem 3 — Delete returned 422, but only from curl

### Symptom

Testing delete from the command line:

```
DELETE status=422
still exists? true
```

Yet the request test `destroy deletes the task` passed, and delete worked in the browser.

### Diagnosis

From `log/development.log`:

```
Started DELETE "/tasks/6" for 127.0.0.1
Processing by TasksController#destroy as */*
Can't verify CSRF token authenticity.
Completed 422 Unprocessable Content
```

A CSRF failure. But the token was fetched from that very page.

### The actual cause

**`per_form_csrf_tokens` is enabled by default in Rails.** Each form's token is bound
to *that form's action URL and HTTP method*. Two forms on the same page get different,
non-interchangeable tokens.

The task show page has multiple forms. The script grabbed the **first** token on the
page — which belonged to the *toggle* form (`PATCH /tasks/6/toggle`) — and used it for
the *delete* form (`DELETE /tasks/6`). Different action, different method, invalid token.

Create and update worked because `/tasks/new` and `/tasks/3/edit` each have only one
form, so "the first token" happened to be the right one.

### The fix

Extract the token from the form that actually contains `_method=delete`. Delete then
returned 302 and the record was gone.

### The lesson

Two things worth saying out loud:

1. **A failing test can be wrong.** The app was correct; the test script was. Always ask
   "is this a real bug or is my test lying?"
2. CSRF tokens in Rails are per-form, not per-session. If you ever script against a Rails
   app, take the token from the specific form you're submitting.

---

## The general debugging method

1. **Read the whole error**, especially the class name — `ArgumentError` and
   `NoMethodError` mean very different things.
2. **Read the whole backtrace**, not the first line. Use `-b` on tests.
3. **Check the log** — `tail -f log/development.log` shows every request, parameter and
   query as it happens.
4. **Reproduce in isolation** — `bin/rails console` to test a model method with no HTTP
   involved.
5. **Question the test, not just the code.**
6. **For anything visual, look at it.** Status codes cannot see a broken page.
