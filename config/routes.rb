Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

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
