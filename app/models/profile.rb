# Profile model
# file: app/models/profile.rb

class Profile < ApplicationRecord

  include ElasticsearchSearchable

  belongs_to :profileable, 
    polymorphic: true,
    required: false
    
  before_validation :format_contact_phone
  before_save :set_full_name, :fix_phone_number
  after_commit :update_relations

  # Validations
  validates_presence_of :first_name, :last_name
  validate :user_age

	enum gender: { unspecified: 0, male: 1, female: 2 }, _suffix: true
	enum salutation: { unspecified: 0, mr: 1, mrs: 2, miss: 3, dr: 4, lord: 5 }, _suffix: true

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :first_name, type: :text, analyzer: 'english'
      indexes :last_name, type: :text, analyzer: 'english'
      indexes :full_name, type: :text, analyzer: 'english'
    end
  end

  def user_age
    errors.add(:birth_date, 'User should be over 18 years old.') if profileable && profileable_type == "User" && birth_date && birth_date > 18.years.ago
  end

  private  

    def update_relations
      Staff.update_profile(self)
    end


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
    
    def fix_phone_number
	  	unless self.contact_phone.nil?
		  	modified_number = self.contact_phone.gsub(/\s+/,'')
		  	modified_number = modified_number.gsub(/[()-+.]/,'').tr('-', '')
				modified_number = modified_number.start_with?('1') &&
												  modified_number.length > 10 ? modified_number[1..-1] : 
																												modified_number	
				self.contact_phone = modified_number	  		
		  end  
	  end
      
end
