# Sample data for development.
# Run with:  bin/rails db:seed
Task.destroy_all

Task.create!(
  title: "Set up the TaskFlow database",
  description: "Create the tasks table with title, description and completed columns.",
  completed: true
)

Task.create!(
  title: "Build the tasks CRUD pages",
  description: "Index, show, new, edit and delete, using RESTful routes.",
  completed: true
)

Task.create!(
  title: "Design the dashboard",
  description: "Show total, completed and pending counts plus a progress bar.",
  completed: false
)

Task.create!(
  title: "Add form validations",
  description: "Title must be present and no longer than 100 characters.",
  completed: false
)

Task.create!(
  title: "Write the README",
  description: nil,
  completed: false
)

puts "Seeded #{Task.count} tasks."
