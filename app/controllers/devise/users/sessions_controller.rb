class Devise::Users::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
end
