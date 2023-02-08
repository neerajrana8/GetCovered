class Devise::Users::PasswordsController < DeviseTokenAuth::PasswordsController
  skip_after_action :update_auth_header, only: [:create, :edit, :update]

end
