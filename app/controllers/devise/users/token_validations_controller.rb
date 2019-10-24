class Devise::Users::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include TokenValidationMethods
end
