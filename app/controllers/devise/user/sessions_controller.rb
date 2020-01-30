class Devise::User::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
end
