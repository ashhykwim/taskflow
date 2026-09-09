Rails.application.routes.draw do
  # The dashboard is the home page.
  root "dashboard#index"

  # `resources :tasks` gives the 7 standard RESTful routes.
  # The extra `patch :toggle` adds  PATCH /tasks/:id/toggle  for the
  # complete / uncomplete button.
  resources :tasks do
    member do
      patch :toggle
    end
  end

  # Health check used by load balancers. Comes with Rails.
  get "up" => "rails/health#show", as: :rails_health_check
end
