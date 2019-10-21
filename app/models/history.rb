class History < ApplicationRecord

  # Active Record Callbacks

  after_initialize :initialize_history
  
  # Relationships
  
  belongs_to :recordable,
  polymorphic: true
    
  belongs_to :authorable,
    polymorphic: true,
    required: false
  
  # Enum Options
  enum action: ['create', 'update', 'remove', 'create_related', 'update_related', 'remove_related'],
    _suffix: true

  private

    def initialize_history
      self.author ||= self.authorable.nil? ? "System" : "#{authorable.class.name}: #{authorable.profile.full_name}"
    end
end
