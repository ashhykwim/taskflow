require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "dashboard renders the stat sections" do
    get root_url
    assert_response :success
    assert_match "Total tasks", response.body
    assert_match "Overall progress", response.body
    assert_match "Recent tasks", response.body
  end

  test "dashboard shows the correct counts" do
    get root_url
    assert_response :success
    # Fixtures give us 1 completed + 1 pending = 2 total, so 50%.
    assert_equal 2, Task.count
    assert_equal 1, Task.completed.count
    assert_equal 1, Task.pending.count
    assert_match "50%", response.body
  end

  test "recent tasks list links to a task" do
    get root_url
    assert_match task_path(tasks(:pending_task)), response.body
  end
end
