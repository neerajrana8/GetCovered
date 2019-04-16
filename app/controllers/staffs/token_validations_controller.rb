class Staffs::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include TokenValidationMethods  
end