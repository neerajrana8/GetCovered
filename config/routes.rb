Rails.application.routes.draw do
  mount_devise_token_auth_for 'SuperAdmin', 
    at: 'v1/utility/auth',
    skip: [:invitations],
    controllers: {
      sessions: 'super_admins/sessions',
      token_validations:  'super_admins/token_validations',
      passwords: 'super_admins/passwords'
    }
            
  mount_devise_token_auth_for 'Staff', 
    at: 'v1/account/auth', 
    skip: [:invitations],
    controllers: {
      sessions: 'staffs/sessions',
      token_validations:  'staffs/token_validations',
      passwords: 'staffs/passwords'
    }

  devise_for :staffs, path: "v1/account/auth", 
    only: [:invitations],
    controllers: { 
      invitations: 'staffs/invitations' 
    }
  
  mount_devise_token_auth_for 'User', 
    at: 'v1/user/auth', 
    skip: [:invitations],
    controllers: { 
      registrations: "users/registrations",
      sessions: 'users/sessions',
      token_validations:  'users/token_validations',
      passwords: 'users/passwords'
    }

  devise_for :users, path: "v1/user/auth", 
    only: [:invitations],
    controllers: { 
      invitations: 'users/invitations' 
    }

  draw :public
  draw :staff
  draw :super_admin
  draw :user
  
end
