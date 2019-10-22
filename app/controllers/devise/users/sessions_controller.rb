class Users::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
end
