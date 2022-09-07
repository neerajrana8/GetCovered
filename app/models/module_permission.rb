# == Schema Information
#
# Table name: module_permissions
#
#  id                    :bigint           not null, primary key
#  application_module_id :bigint
#  permissable_type      :string
#  permissable_id        :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class ModulePermission < ApplicationRecord
  belongs_to :application_module
  belongs_to :permissable, 
    polymorphic: true
end
