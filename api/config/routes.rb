Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "locations", to: "locations#index"
    get "locations/:location_id/employees", to: "locations#employees"
    get "locations/:location_id/schedule", to: "locations#schedule"
    get "locations/:location_id/payroll", to: "locations#payroll"
    get "locations/:location_id/swap_requests", to: "swap_requests#index"

    resources :shifts, only: %i[create update destroy] do
      resources :swap_requests, only: :create
    end
    post "swap_requests/:id/approve", to: "swap_requests#approve"
    post "swap_requests/:id/reject", to: "swap_requests#reject"

    # Employee app
    get "employees/:employee_id/week", to: "employees#week"
    post "employees/:employee_id/claims/:shift_id", to: "employees#claim"
  end
end
