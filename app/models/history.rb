class History < ApplicationRecord
  belongs_to :recordable,
  polymorphic: true
    
  belongs_to :authorable,
    polymorphic: true,
    required: false
  
  # Enum Options
  enum action: ['create', 'update', 'remove', 'create_related', 'update_related', 'remove_related'], _suffix: true
  
  # History.author
  # returns string of System process or Authorable model
  def author
    if authorable.nil?
      return "System"
    else
      return "#{authorable.class.name}: #{authorable.profile.full_name}"
    end
  end
end
