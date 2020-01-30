class Devise::User::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include TokenValidationMethods
end
