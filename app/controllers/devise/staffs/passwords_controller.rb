class Staffs::PasswordsController < DeviseTokenAuth::PasswordsController
  include PasswordMethods
end
