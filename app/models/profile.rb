# Profile model
# file: app/models/profile.rb

class Profile < ApplicationRecord

  include ElasticsearchSearchable

  belongs_to :profileable, 
    polymorphic: true,
    required: false
    
  before_validation :format_contact_phone
  before_save :set_full_name

  # Validations
  validates_presence_of :first_name, :last_name
  validate :user_age

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :first_name, type: :text, analyzer: 'english'
      indexes :last_name, type: :text, analyzer: 'english'
      indexes :full_name, type: :text, analyzer: 'english'
    end
  end

  def user_age
    errors.add(:birth_date, 'User should be over 18 years old.') if profileable && profileable_type == "User" && birth_date > 18.years.ago
  end

  private  

    # Profile.format_contact_phone
    def format_contact_phone
      if self.contact_phone == ""
        self.contact_phone = nil
        return
      end
      self.contact_phone.delete!('^0-9') unless self.contact_phone.nil?
    end
    
    # Profile.set_full_name
    def set_full_name
      name_string = [title, first_name, middle_name, last_name, suffix].compact
                                                                       .join(' ')
                                                                       .gsub(/\s+/, ' ')
                                                                       .strip
      self.full_name = name_string
    end
      
end
