# frozen_string_literal: true

Rails.application.routes.draw do
  get 'current_user/index'
  devise_for :users,
  controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }
  resources :reservations do
    member do
      patch :cancel
    end
  end
  resources :cars do
    member do
      get :availability
    end
  end
  get '/current_user', to: 'current_user#index'
end
