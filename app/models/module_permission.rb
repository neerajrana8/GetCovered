class ModulePermission < ApplicationRecord
  belongs_to :application_module
  belongs_to :permissible, 
    polymorphic: true
end
