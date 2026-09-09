class Task < ApplicationRecord
  # Validations: run automatically before every save/create/update.
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }

  # Scopes: named, reusable, chainable queries.
  scope :completed, -> { where(completed: true) }
  scope :pending,   -> { where(completed: false) }
  scope :recent,    -> { order(created_at: :desc) }

  # Flip the completed flag. Called by TasksController#toggle.
  def toggle_completed!
    update(completed: !completed)
  end

  def status_label
    completed? ? "Completed" : "Pending"
  end
end
