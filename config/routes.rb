Rails.application.routes.draw do
  post '/signup', to: 'authentication#signup'
  post '/login', to: 'authentication#login'
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  resources :routes, only: [:index, :create, :show, :destroy]
end