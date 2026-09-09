# TaskFlow — Project Notes

Everything about this project, written so you can explain all of it out loud.

## Read in this order

| # | File | What it covers |
|---|---|---|
| 01 | `01-build-commands.md` | Every command that created this project, in order |
| 02 | `02-request-flow.md` | What happens between a click and the page appearing |
| 03 | `03-file-by-file.md` | Every file, what it does, why it exists |
| 04 | `04-routes-and-http.md` | All 9 routes, which action each hits, how to test them |
| 05 | `05-database-and-model.md` | Schema, migration, validations, scopes, console |
| 06 | `06-views-and-erb.md` | Layout, partials, forms, how HTML gets built |
| 07 | `07-how-to-change-things.md` | Recipes: add a field, add a page, change a rule |
| 08 | `08-interview-questions.md` | ~60 questions with answers tied to this code |
| 09 | `09-demo-script.md` | Exactly what to show Aadarsh bhaiya, in order |
| 10 | `10-problems-we-hit.md` | Real bugs in this project and how they were found |

## The 30-second summary

> TaskFlow is a task manager built with Ruby on Rails 8. It's a server-rendered
> app — Rails generates the HTML and sends complete pages to the browser. There's
> no separate frontend framework and no API layer.
>
> There's one model, `Task`, with a title, description and a completed flag.
> It has full CRUD through standard RESTful routes, plus one extra route to
> toggle a task complete. A dashboard shows counts and a completion percentage.
>
> Styling is Bootstrap 5, vendored locally. Data is in SQLite. There are 20 tests
> covering the model and every controller action.

## Honesty note

If bhaiya asks whether you wrote all of this yourself: say what's true. You can
still own it completely by being able to explain every line, justify every
decision, and change anything on the spot. That's what file 07 is for — being
able to *modify* the code live is the strongest possible proof of understanding.

## The four things to be able to do without notes

1. Trace a request end to end (file 02)
2. Name all 7 RESTful actions and why `toggle` isn't one of them (file 04)
3. Explain the difference between `redirect_to` and `render` (file 08)
4. Add a new field to Task, live, while he watches (file 07)
