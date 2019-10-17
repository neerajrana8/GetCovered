Rails.application.routes.draw do
            
  mount_devise_token_auth_for 'Staff', 
    at: 'v2/account/auth', 
    skip: [:invitations],
    controllers: {
      sessions: 'staffs/sessions',
      token_validations:  'staffs/token_validations',
      passwords: 'staffs/passwords'
    }

  devise_for :staffs, path: "v2/account/auth", 
    only: [:invitations],
    controllers: { 
      invitations: 'staffs/invitations' 
    }
  
  mount_devise_token_auth_for 'User', 
    at: 'v2/user/auth', 
    skip: [:invitations],
    controllers: { 
      registrations: "users/registrations",
      sessions: 'users/sessions',
      token_validations:  'users/token_validations',
      passwords: 'users/passwords'
    }

  devise_for :users, path: "v2/user/auth", 
    only: [:invitations],
    controllers: { 
      invitations: 'users/invitations' 
    }
  
  get 'v2/health-check', to: 'v2#health_check', as: :health_check
  
  namespace :v2 do
    draw :public
    draw :staff
    draw :user
  end
  
end
