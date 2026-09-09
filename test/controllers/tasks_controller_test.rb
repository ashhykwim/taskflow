require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup { @task = tasks(:pending_task) }

  test "index lists tasks" do
    get tasks_url
    assert_response :success
    assert_match @task.title, response.body
  end

  test "index filters by status" do
    get tasks_url(status: "completed")
    assert_response :success
    assert_match tasks(:completed_task).title, response.body
    assert_no_match @task.title, response.body
  end

  test "show displays a task" do
    get task_url(@task)
    assert_response :success
    assert_match @task.title, response.body
  end

  test "new renders the form" do
    get new_task_url
    assert_response :success
  end

  test "create saves a valid task and redirects" do
    assert_difference("Task.count", 1) do
      post tasks_url, params: { task: { title: "Brand new task", description: "Details" } }
    end
    assert_redirected_to task_url(Task.last)
    follow_redirect!
    assert_match "Task was created successfully.", response.body
  end

  test "create rejects an invalid task and re-renders the form" do
    assert_no_difference("Task.count") do
      post tasks_url, params: { task: { title: "" } }
    end
    assert_response :unprocessable_entity
    assert_match "Title can&#39;t be blank", response.body
  end

  test "edit renders the form" do
    get edit_task_url(@task)
    assert_response :success
  end

  test "update saves changes" do
    patch task_url(@task), params: { task: { title: "Renamed task" } }
    assert_redirected_to task_url(@task)
    assert_equal "Renamed task", @task.reload.title
  end

  test "update rejects invalid changes" do
    patch task_url(@task), params: { task: { title: "" } }
    assert_response :unprocessable_entity
  end

  test "toggle marks a task completed and back again" do
    patch toggle_task_url(@task)
    assert @task.reload.completed?

    patch toggle_task_url(@task)
    assert_not @task.reload.completed?
  end

  test "destroy deletes the task" do
    assert_difference("Task.count", -1) do
      delete task_url(@task)
    end
    assert_redirected_to tasks_url
  end
end
