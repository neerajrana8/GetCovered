class SuperAdmins::PasswordsController < DeviseTokenAuth::PasswordsController
  include PasswordMethods
end