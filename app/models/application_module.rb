# == Schema Information
#
# Table name: application_modules
#
#  id         :bigint           not null, primary key
#  title      :string
#  slug       :string
#  nodes      :jsonb
#  enabled    :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ApplicationModule < ApplicationRecord
  
  include SetSlug
  
  # Validations
  
  validates_presence_of :title, :slug

end
