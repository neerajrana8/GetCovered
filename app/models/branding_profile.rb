##
# Branding Profile Model
# file: +app/models/branding_profile.rb+

class BrandingProfile < ApplicationRecord
  
  after_initialize  :initialize_branding_profile
  after_save :check_default
  
  validates_presence_of :title, :url
  
  belongs_to :profileable, 
    polymorphic: true
    
    
  scope :default, -> { where(default: true) }
    
  private
  
    def initialize_branding_profile
      self.styles ||= {}
      # Admin Styles Options
      self.styles['admin'] ||= {}
      self.styles['admin']['colors'] ||= {}
      self.styles['admin']['colors']['primary']   ||= "#000000"
      self.styles['admin']['colors']['highlight'] ||= "#FFFFFF"
      self.styles['admin']['colors']['warning']   ||= "#FF0000"
      self.styles['admin']['content'] ||= {}
      # Client Styles Options
      self.styles['client'] ||= {}  
      self.styles['client']['colors'] ||= {}
      self.styles['client']['colors']['primary']   ||= "#000000"
      self.styles['client']['colors']['highlight'] ||= "#FFFFFF"
      self.styles['client']['colors']['warning']   ||= "#FF0000"
      self.styles['client']['content'] ||= {}
    end
    
    def check_default
      if profileabe.branding_profiles.count > 1 && 
         default?
        
        profileabe.branding_profiles
                  .where(default: true)
                  .where()
                  .not(id: id)
                  .update default: false
      end  
    end
  
end
