#
# RecordChange Concern
# file: app/models/concerns/record_change.rb

module RecordChange
  extend ActiveSupport::Concern

  included do
    before_save :record_change,
      if: Proc.new { |r| r.persisted? }
      
    after_create :record_create
  end

  def update_as(updater, update_params)
    @author = updater
    update(update_params)
  end
  
  def create_as(creator, create_as_params)
    @author = creator
    if create_as_params.nil?
      create
    else
      create(create_as_params)
    end
  end
  
  def save_as(saver)
    @author = saver
    save  
  end
  
  def invite_as!(inviter, invite_as_params = nil, send_invite: true)
    @author = inviter
    tr = nil
    if send_invite
      tr = invite!(invite_as_params)
    else
      invite! {|u| u.skip_invitation = true }
      tr = id.nil? ? nil : true
    end
    tr
  end

  def record_change
    
    author = instance_variable_defined?(:@author) ? @author : nil
    changes = Hash.new

    self.class.columns.each do |column|
      if self.will_save_change_to_attribute?(column.name) &&
         (!self.respond_to?(:history_whitelist, true) || history_whitelist.include?(column.name.to_sym)) &&
         (!self.respond_to?(:history_blacklist, true) || !history_blacklist.include?(column.name.to_sym))

        if self.respond_to?(:history_special_messages, true) && history_special_messages.has_key?(column.name.to_sym)
          changes[column.name] = {
            description: history_special_messages[column.name.to_sym]
          }
        else
          changes[column.name] = {
            previous_value: self.attribute_in_database(column.name),
            new_value: self.send(column.name)
          }
        end
      end
    end
      
    unless changes.empty?  
	    self.histories.create(authorable: author, data: changes, action: 'update')
	    author.histories.create(authorable: author, data: changes, action: 'update') unless author.nil?
		end
    remove_instance_variable(:@author) if instance_variable_defined?(:@author)

  end


  def record_create
    author = instance_variable_defined?(:@author) ? @author : nil
    
	  unless self.respond_to?(:create_ahistorically, true) && create_ahistorically
	  	self.histories.create(authorable: author, action: 'create')
	  	author.histories.create(authorable: author, data: related_create_hash(self.class.name.downcase.to_sym, self), action: 'create_related') unless author.nil? 
	  end
	  
    (self.respond_to?(:related_classes_through, true) ? related_classes_through : []).each do |related|
      ([:has_many, :has_and_belongs_to_many].include?(self.class.reflect_on_association(related).macro) ? self.send(related) : [ self.send(related) ]).each do |related_model|
        related_model
          .histories
          .create(authorable: author, data: related_create_hash(related, related_model), action: 'create_related') unless related_model.nil?
      end
    end
    remove_instance_variable(:@author) if instance_variable_defined?(:@author)
  end

end
