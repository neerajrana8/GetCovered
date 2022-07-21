# == Schema Information
#
# Table name: histories
#
#  id              :bigint           not null, primary key
#  action          :integer          default("create")
#  data            :json
#  recordable_type :string
#  recordable_id   :bigint
#  authorable_type :string
#  authorable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author          :string
#
class History < ApplicationRecord
  # Active Record Callbacks

  after_initialize :initialize_history
  
  # Relationships
  
  belongs_to :recordable, polymorphic: true
  belongs_to :authorable, polymorphic: true, required: false
  
  # Enum Options
  enum action: %w[create update remove create_related update_related remove_related], _suffix: true

  private

  def initialize_history
    self.author ||= authorable.nil? ? 'System' : "#{authorable.class.name}: #{authorable.profile.full_name}"
  end
end
