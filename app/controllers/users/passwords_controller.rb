class Users::PasswordsController < DeviseTokenAuth::PasswordsController
  include PasswordMethods
end
