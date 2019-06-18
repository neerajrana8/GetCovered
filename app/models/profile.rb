# Profile model
# file: app/models/profile.rb

class Profile < ApplicationRecord
  belongs_to :profileable, 
    polymorphic: true,
    required: false
    
  before_validation :format_contact_phone
  before_save :set_full_name  

  # Validations
  validates_presence_of :first_name, :last_name

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
