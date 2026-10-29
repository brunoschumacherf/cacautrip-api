Rails.application.routes.draw do
  post '/signup', to: 'authentication#signup'
  post '/login', to: 'authentication#login'
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  resources :routes, only: [:index, :create, :show, :destroy]
  post '/professional_profiles/guide', to: 'professional_profiles#create_guide'
  post '/professional_profiles/driver', to: 'professional_profiles#create_driver'
  get '/professional_profiles/guides', to: 'professional_profiles#index_guides'
  get '/professional_profiles/drivers', to: 'professional_profiles#index_drivers'
  resources :bookings, only: [:create]
  get '/bookings/professional/:professional_id', to: 'bookings#professional_requests'
  patch '/bookings/:id/respond', to: 'bookings#respond_booking'

end