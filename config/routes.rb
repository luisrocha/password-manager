Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :browser do
      post "auth/unlock", to: "auth#unlock"
      post "credentials/search", to: "credentials#search"
      post "credentials", to: "credentials#create"
      get "credentials/:id", to: "credentials#show"
      patch "credentials/:id", to: "credentials#update"
      delete "credentials/:id", to: "credentials#destroy"
    end

    namespace :mobile do
      post "vault_pairings/redeem", to: "vault_pairings#redeem"
    end
  end

  get "unlock", to: "sessions#new"
  post "unlock", to: "sessions#create"
  post "unlock/verify_setup_token", to: "sessions#verify_setup_token"
  post "unlock/verify_backup_key", to: "sessions#verify_backup_key"
  delete "lock", to: "sessions#destroy"
  get "totp_challenge", to: "totp_challenges#new"
  post "totp_challenge", to: "totp_challenges#create"
  get "security", to: "security#index"
  get "connected_apps", to: "connected_apps#index"
  post "connected_apps/mobile_pairings", to: "connected_apps#create_mobile_pairing"
  delete "connected_apps/mobile_devices/:id", to: "connected_apps#revoke_mobile_device", as: :connected_apps_mobile_device
  resource :totp_setting, only: %i[create destroy] do
    post :confirm
  end

  root "credentials#index"

  resources :credentials, only: %i[index new create edit update destroy] do
    collection do
      get :import
      post :import
    end
  end
end
