Rails.application.routes.draw do
  resources :events, only: %i(index create)
  resources :integrations, only: %i(index show)
end
