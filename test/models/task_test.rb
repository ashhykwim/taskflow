require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "is valid with a title" do
    assert Task.new(title: "Something").valid?
  end

  test "is invalid without a title" do
    task = Task.new(title: "")
    assert_not task.valid?
    assert_includes task.errors.full_messages, "Title can't be blank"
  end

  test "is invalid when the title is too long" do
    assert_not Task.new(title: "a" * 101).valid?
  end

  test "defaults to not completed" do
    task = Task.create!(title: "Fresh task")
    assert_not task.completed?
  end

  test "toggle_completed! flips the flag" do
    task = Task.create!(title: "Toggle me")
    task.toggle_completed!
    assert task.reload.completed?
    task.toggle_completed!
    assert_not task.reload.completed?
  end

  test "completed and pending scopes filter correctly" do
    assert_includes Task.completed, tasks(:completed_task)
    assert_not_includes Task.completed, tasks(:pending_task)
    assert_includes Task.pending, tasks(:pending_task)
  end
end
