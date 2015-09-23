Rails.application.routes.draw do
  resources :events, only: %i(create index)
  resources :integrations, only: %i(index show)
end
