class DashboardController < ApplicationController
  def index
    @total_count     = Task.count
    @completed_count = Task.completed.count
    @pending_count   = Task.pending.count
    @recent_tasks    = Task.recent.limit(5)

    @completion_percentage =
      @total_count.zero? ? 0 : (@completed_count.to_f / @total_count * 100).round
  end
end
