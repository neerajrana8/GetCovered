class Users::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include TokenValidationMethods
end
