Rails.application.routes.draw do
  devise_for :admin_users
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :onboarding do
    resources :uploads, only: %i[new create show], param: :access_token
    resources :profiles, only: %i[edit update show], param: :access_token
  end

  namespace :admin do
    resources :candidate_profiles, only: %i[index show]
    root to: "candidate_profiles#index"
  end

  # Defines the root path route ("/")
  root "onboarding/uploads#new"
end
