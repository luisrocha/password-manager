Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :browser do
      post "auth/unlock", to: "auth#unlock"
      post "credentials/search", to: "credentials#search"
      post "credentials", to: "credentials#create"
      patch "credentials/:id", to: "credentials#update"
      delete "credentials/:id", to: "credentials#destroy"
    end
  end

  get "unlock", to: "sessions#new"
  post "unlock", to: "sessions#create"
  delete "lock", to: "sessions#destroy"

  root "credentials#index"

  resources :credentials, only: %i[index create edit update destroy] do
    collection do
      post :import
    end
  end
end
