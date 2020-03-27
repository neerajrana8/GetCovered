require 'sidekiq/web'

Rails.application.routes.draw do
  
  mount_devise_token_auth_for 'User',
    at: 'v2/user/auth',
    skip: [:invitations],
    controllers: {
      sessions: 'devise/users/sessions',
      token_validations: 'devise/users/token_validations',
      passwords: 'devise/users/passwords',
      registrations: 'devise/users/registrations'
    }
  
  devise_for :users, path: 'v2/user/auth',
    defaults: { format: :json },
    only: [:invitations],
    controllers: {
      invitations: 'devise/users/invitations'
    }
  
  mount_devise_token_auth_for 'Staff',
    at: 'v2/staff/auth',
    skip: [:invitations],
    controllers: {
      sessions: 'devise/staffs/sessions',
      token_validations: 'devise/staffs/token_validations',
      passwords: 'devise/staffs/passwords'
    }
  
  devise_for :staffs, path: 'v2/staff/auth',
    defaults: { format: :json },
    only: [:invitations],
    controllers: {
      invitations: 'devise/staffs/invitations'
    }
  
  get 'v2/health-check', to: 'v2#health_check', as: :health_check
  
  namespace :v2, defaults: { format: 'json' } do
    concern :reportable do
      resources :reports, controller: '/v2/reports', only: [:index, :show] do
        collection do
          get '/available-range', to: '/v2/reports#available_range'
          get '/generate',        to: '/v2/reports#generate'
        end
      end
    end

    draw :user
    draw :staff_account
    draw :staff_agency
    draw :staff_super_admin
    draw :public
  end

  root to: "application#redirect_home"
end
