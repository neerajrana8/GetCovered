# Profile model
# file: app/models/profile.rb

class Profile < ApplicationRecord

  belongs_to :profileable, polymorphic: true, required: false

  before_validation :format_contact_phone
  before_save :set_full_name, :fix_phone_number

  # Validations(remove validation for profiles for leads)
  validates_presence_of :first_name, :last_name, unless: -> { [Lead].include?(profileable.class) }

  enum gender: { unspecified: 0, male: 1, female: 2, other: 4 }, _suffix: true
  enum salutation: { unspecified: 0, mr: 1, mrs: 2, miss: 3, dr: 4, lord: 5 }
  enum language: { en: 0, es: 1 }

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
