class SuperAdmins::SessionsController < DeviseTokenAuth::SessionsController
  include SessionsMethods
end
