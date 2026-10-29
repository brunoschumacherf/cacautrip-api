Rails.application.routes.draw do
  get '/admin', to: redirect('/gestao')
  namespace :backoffice, path: 'gestao' do
    resources :support_chats, path: 'atendimentos', only: [:index, :show] do
      member do
        get :messages, path: 'mensagens'
        post :reply, path: 'responder'
        post :close, path: 'encerrar'
      end
    end
    get '/', to: 'dashboard#index', as: :root
    get '/entrar', to: 'sessions#new', as: :login
    post '/entrar', to: 'sessions#create'
    delete '/sair', to: 'sessions#destroy', as: :logout
    get '/relatorios', to: 'reports#index', as: :reports
    get '/comissoes', to: 'finance#commission', as: :commission
    patch '/comissoes', to: 'finance#update_commission'
    post '/reservas/:id/cancelar', to: 'finance#refund', as: :cancel_booking
    get '/registros/:resource', to: 'records#index', as: :records
    get '/registros/:resource/novo', to: 'records#new', as: :new_record
    post '/registros/:resource', to: 'records#create'
    get '/registros/:resource/:id', to: 'records#show', as: :record
    get '/registros/:resource/:id/editar', to: 'records#edit', as: :edit_record
    patch '/registros/:resource/:id', to: 'records#update'
    delete '/registros/:resource/:id', to: 'records#destroy'
  end
  mount ActionCable.server => '/cable'
  post '/cable_ticket', to: 'cable_tickets#create'
  get '/health', to: 'health#show'
  post '/signup', to: 'authentication#signup'
  post '/login', to: 'authentication#login'
  post '/auth/google/start', to: 'google_authentication#start'
  get '/auth/google/callback', to: 'google_authentication#callback'
  post '/auth/google/finish', to: 'google_authentication#finish'
  get '/me', to: 'authentication#me'
  patch '/me', to: 'authentication#update_profile'
  post '/me/verify_gov', to: 'authentication#verify_gov'
  get '/privacy/export', to: 'privacy#export'
  post '/privacy/deletion_request', to: 'privacy#request_deletion'
  get '/catalog', to: 'catalog#index'
  get '/destinations/:id', to: 'catalog#show'
  get '/shared_routes/:token', to: 'shared_routes#show'
  post '/routes/suggest', to: 'routes#suggest'
  post '/routes/:id/share', to: 'routes#share'
  delete '/routes/:id/share', to: 'routes#unshare'
  resources :routes, only: [:index, :create, :show, :update, :destroy]
  post '/recommendations', to: 'recommendations#create'
  get '/trails/mine', to: 'trails#mine'
  get '/trails/:id/edit', to: 'trails#edit'
  post '/trails/:id/duplicate', to: 'trails#duplicate'
  resources :trails, only: [:index, :show, :create, :update, :destroy]
  post '/trails/:trail_id/departures', to: 'trail_departures#create'
  patch '/trail_departures/:id', to: 'trail_departures#update'
  post '/trail_departures/:id/cancel', to: 'trail_departures#cancel'
  get '/trail_departures/:id/participants', to: 'trail_departures#participants'
  post '/trail_departures/:departure_id/reserve', to: 'trail_reservations#create'
  post '/professional_profiles/guide', to: 'professional_profiles#create_guide'
  post '/professional_profiles/driver', to: 'professional_profiles#create_driver'
  get '/professional_profiles/mine', to: 'professional_profiles#mine'
  get '/professional_profiles/commission', to: 'professional_profiles#commission'
  get '/professional_profiles/guides', to: 'professional_profiles#index_guides'
  get '/professional_profiles/drivers', to: 'professional_profiles#index_drivers'
  get '/professional_profiles/:kind/:id', to: 'professional_profiles#show'
  get '/bookings/requests', to: 'bookings#professional_requests'
  get '/bookings/professional/:professional_id', to: 'bookings#professional_requests'
  resources :bookings, only: [:index, :create, :show] do
    member do
      patch :cancel
      patch :complete
      post :pay
      post :payment_status
      patch :respond, action: :respond_booking
      post :conversation
      post :counteroffer
      patch :accept_offer
    end
  end
  resources :conversations, only: [:index, :create]
  get '/conversations/:id/messages', to: 'conversations#messages'
  post '/conversations/:id/messages', to: 'conversations#send_message'
  get '/wallet', to: 'wallets#show'
  post '/wallet/payout', to: 'wallets#payout'
  resources :reviews, only: [:create]
  post '/reports', to: 'reviews#report'
  resources :notifications, only: [:index, :update]
  resources :subscriptions, only: [:index, :create, :update, :destroy]
  resources :subscription_orders, only: [:create] do
    member do
      post :pay
      post :payment_status
    end
  end
  get '/support', to: 'support#index'
  post '/support', to: 'support#create'
  post '/support/ask', to: 'support#ask'
  get '/support/:id', to: 'support#show'
  post '/support/:id/messages', to: 'support#message'
  post '/support/:id/human', to: 'support#human'
  get '/admin/dashboard', to: 'admin#dashboard'
  patch '/admin/commission', to: 'admin#commission'
  get '/admin/:resource', to: 'admin#index'
  post '/admin/:resource', to: 'admin#create'
  patch '/admin/:resource/:id', to: 'admin#update'
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
end
