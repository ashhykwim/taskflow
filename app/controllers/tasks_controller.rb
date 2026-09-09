class TasksController < ApplicationController
  # Runs set_task before these actions so we don't repeat the lookup.
  before_action :set_task, only: [ :show, :edit, :update, :destroy, :toggle ]

  # GET /tasks
  def index
    @tasks = Task.recent

    # Optional filter: /tasks?status=completed
    case params[:status]
    when "completed" then @tasks = @tasks.completed
    when "pending"   then @tasks = @tasks.pending
    end
  end

  # GET /tasks/:id
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  # GET /tasks/:id/edit
  def edit
  end

  # POST /tasks
  def create
    @task = Task.new(task_params)

    if @task.save
      redirect_to @task, notice: "Task was created successfully."
    else
      # Re-render the form so the user keeps their input and sees the errors.
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /tasks/:id
  def update
    if @task.update(task_params)
      redirect_to @task, notice: "Task was updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "Task was deleted."
  end

  # PATCH /tasks/:id/toggle
  def toggle
    @task.toggle_completed!
    redirect_back fallback_location: tasks_path,
                  notice: "Task marked as #{@task.status_label.downcase}."
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  # Strong parameters: only these fields may be written from a form.
  def task_params
    params.require(:task).permit(:title, :description, :completed)
  end
end
