require 'sidekiq/web'

Rails.application.routes.draw do
  
  
  mount_devise_token_auth_for 'User',
    at: 'v2/user/auth',
    skip: [:invitations],
    controllers: {
      sessions: 'devise/user/sessions',
      token_validations: 'devise/user/token_validations',
      passwords: 'devise/user/passwords'
    }
  
  devise_for :users, path: 'v2/user/auth',
    defaults: { format: :json },
    only: [:invitations],
    controllers: {
      invitations: 'devise/user/invitations'
    }
  
  mount_devise_token_auth_for 'Staff',
    at: 'v2/staff/auth',
    skip: [:invitations],
    controllers: {
      sessions: 'devise/staff/sessions',
      token_validations: 'devise/staff/token_validations',
      passwords: 'devise/staff/passwords'
    }
  
  devise_for :staffs, path: 'v2/staff/auth',
    defaults: { format: :json },
    only: [:invitations],
    controllers: {
      invitations: 'devise/staff/invitations'
    }
  
  
  namespace :v2, defaults: { format: 'json' } do
    draw :user
    draw :staff_account
    draw :staff_agency
    draw :staff_super_admin
    draw :public
  end
  
end
