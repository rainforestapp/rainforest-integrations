Rails.application.routes.draw do
  match '/*all', to: 'application#cors_preflight_check', via: [:options]
  resources :events, only: %i(index create)
  resources :integrations, only: %i(index show)
end
