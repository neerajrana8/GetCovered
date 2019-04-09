class ModulePermission < ApplicationRecord
  belongs_to :application_module
  belongs_to :permissable, 
    polymorphic: true
end
