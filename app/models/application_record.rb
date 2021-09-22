
# hideous monkey patch
module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements
      alias :old_trans :transaction
    
      def transaction(*largs, **kargs, &barg)
        ApplicationRecord.increment_transaction_id if ActiveRecord::Base.connection.open_transactions == 0
        puts "TRANNY ENTER #{ApplicationRecord.instance_variable_get(:@gc_ar_base_correct_dirty_transaction_id)}" if ActiveRecord::Base.connection.open_transactions == 0
        old_trans(*largs, **kargs, &barg)
        puts "TRANNY EXIT #{ApplicationRecord.instance_variable_get(:@gc_ar_base_correct_dirty_transaction_id)}" if ActiveRecord::Base.connection.open_transactions == 0
      end
    end
  end
end


class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  # below is a fix for:
  #  1) The AR bug where locking a record destroys its previous_changes dirty data, and
  #  2) The AR design oversight where previous_changes isn't cumulative within a transaction (and thus after_commit can't determine what was changed over the course of a transaction)
  
  def self.transaction_id
    connection.open_transactions == 0 ? nil : @gc_ar_base_correct_dirty_transaction_id
  end
  
  def self.increment_transaction_id
    @gc_ar_base_correct_dirty_mask ||= 2**64 - 1
    @gc_ar_base_correct_dirty_transaction_id ||= 0
    @gc_ar_base_correct_dirty_transaction_id = (@gc_ar_base_correct_dirty_transaction_id + 1) & @gc_ar_base_correct_dirty_mask
  end
  
  before_save :gc_ar_base_correct_dirty_before_transaction
  after_save :gc_ar_base_correct_dirty_for_transaction
  after_commit :gc_ar_base_correct_dirty_after_transaction
  after_rollback :gc_ar_base_correct_dirty_after_transaction
  
  def gc_ar_base_correct_dirty_before_transaction
    # MOOSE WARNING: if we are in a new transaction we want to push a new mbls hash onto the stack
    puts "CHECKING #{ApplicationRecord.transaction_id} != #{@gc_ar_base_correct_dirty_tid}"
    if ApplicationRecord.transaction_id != @gc_ar_base_correct_dirty_tid
      @gc_ar_base_correct_dirty_tid = ApplicationRecord.transaction_id
      (@gc_ar_base_correct_dirty_mbls ||= []).push({})
      gc_ar_base_correct_dirty_restoration_time
    end
  end
  
  def gc_ar_base_correct_dirty_for_transaction
    self.previous_changes.each do |field, changez|
      # correct field history in our internal moosehopper
      if @gc_ar_base_correct_dirty_mbls.last.has_key?(field)
        @gc_ar_base_correct_dirty_mbls.last[field][1] = changez[1]
      else
        @gc_ar_base_correct_dirty_mbls.last[field] = [changez[0], changez[1]]
      end
    end
    gc_ar_base_correct_dirty_restoration_time
  end
  
  def gc_ar_base_correct_dirty_restoration_time
    if @gc_ar_base_correct_dirty_mbls && @gc_ar_base_correct_dirty_mbls.last
    
      # THIS IS A BETTER WAY OF DOING IT -- but setting @attributes this way doesn't solve our problem. We need to make a proper mutationtracker when mutations_before_last_save is a NullMutationTracker. And I don't know how yet. Workaround below.
      self.instance_variable_set(:@mutations_before_last_save, ActiveModel::MutationTracker.new(self.instance_variable_get(:@attributes))) if self.send(:mutations_before_last_save).class == ActiveModel::NullMutationTracker
      @gc_ar_base_correct_dirty_mbls.last.each do |field, changez|
        if self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
          self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
        end
        self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value_before_type_cast, changez[0])
        self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value, changez[0])
        self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
        self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@value, changez[1])
      end
      
      #@gc_ar_base_correct_dirty_mbls.last.each do |field, changez|
      #  if self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
      #    self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
      #  end
      #  self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute)&.instance_variable_set(:@value_before_type_cast, changez[0])
      #  self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute)&.instance_variable_set(:@value, changez[0])
      #  self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
      #  self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@value, changez[1])
      #end
      #self.send(:changes_applied)
    end
  end
  
  def gc_ar_base_correct_dirty_after_transaction

    if ApplicationRecord.transaction_id != @gc_ar_base_correct_dirty_tid
      @gc_ar_base_correct_dirty_mbls.pop
      gc_ar_base_correct_dirty_restoration_time
    end
  end
  
  def lock!(*meth, **am, &phetamine)
    super(*meth, **am, &phetamine)
    gc_ar_base_correct_dirty_restoration_time
  end
  
end
