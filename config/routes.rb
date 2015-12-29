Rails.application.routes.draw do
  resources :events, only: %i(index create)
  resources :integrations, only: %i(show)
  match '/integrations', to: 'integrations#index', via: [:options, :get]
end
