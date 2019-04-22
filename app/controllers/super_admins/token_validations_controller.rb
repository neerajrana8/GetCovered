class SuperAdmins::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include TokenValidationMethods
end
