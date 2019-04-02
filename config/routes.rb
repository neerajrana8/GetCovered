Rails.application.routes.draw do
  mount_devise_token_auth_for 'SuperAdmin', at: '/v2/auth'

  mount_devise_token_auth_for 'Staff', at: 'auth'
  as :staff do
    # Define routes for Staff within this block.
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
