Rails.application.routes.draw do
  mount_devise_token_auth_for 'SuperAdmin', at: '/v2/auth'

  mount_devise_token_auth_for 'Staff', at: 'auth'

  mount_devise_token_auth_for 'User', at: 'auth'

  draw :public
  draw :staff
  draw :superadmin
  draw :user
  
end
