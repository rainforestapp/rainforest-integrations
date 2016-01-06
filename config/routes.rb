Rails.application.routes.draw do
  match '/*all', to: 'application#cors_preflight_check', via: [:options]
  resources :events, only: %i(index create)
  resources :integrations, only: %i(index show)

  # OAuth Routes
  post '/oauth/request-token', to: 'oauth#request_token'
  get '/oauth/access-token', to: 'oauth#access_token'
end
