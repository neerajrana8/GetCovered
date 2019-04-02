Rails.application.routes.draw do
  mount_devise_token_auth_for 'SuperAdmin', at: '/v2/auth'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
