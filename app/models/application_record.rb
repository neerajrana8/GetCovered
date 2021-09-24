

# hideous monkey patch
module ActiveRecord
  module ConnectionAdapters
    module DatabaseStatements
      alias :old_trans :transaction
    
      def transaction(*largs, **kargs, &barg)
        ApplicationRecord.increment_transaction_id if ActiveRecord::Base.connection.open_transactions == 0
        old_trans(*largs, **kargs, &barg)
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
  
  
  
  def mutations_within_transaction
    @mutations_within_transactions&.last || ActiveModel::NullMutationTracker.instance
  end
  
  def saved_change_to_attribute_within_transaction?(attr_name, **options)
    mutations_within_transaction.changed?(attr_name, **options)
  end
  
  
  
  
  
  before_save :gc_ar_base_correct_dirty_before_transaction
  after_save :gc_ar_base_correct_dirty_for_transaction
  after_commit :gc_ar_base_correct_dirty_after_transaction
  after_rollback :gc_ar_base_correct_dirty_after_transaction
  
  def gc_ar_base_correct_dirty_before_transaction
    if ApplicationRecord.transaction_id != @gc_ar_base_correct_dirty_tid
      @gc_ar_base_correct_dirty_tid = ApplicationRecord.transaction_id
      (@mutations_within_transactions ||= []).push(ActiveModel::AttributeMutationTracker.new(self.instance_variable_get(:@attributes)))
    end
  end
  
  
  def gc_ar_base_correct_dirty_apply_changes
    lord_of_mutants = @mutations_within_transactions.last
    self.previous_changes.each do |field, changez|
      if lord_of_mutants.send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
        lord_of_mutants.send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
        #lord_of_mutants.send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value_before_type_cast, changez[0])
        #lord_of_mutants.send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value, changez[0])
      end
      lord_of_mutants.send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
      lord_of_mutants.send(:attributes)[field].instance_variable_set(:@value, changez[1])
    end
  end
  
  
  def gc_ar_base_correct_dirty_for_transaction
    gc_ar_base_correct_dirty_apply_changes
  end
  
  def gc_ar_base_correct_dirty_after_transaction
    if ApplicationRecord.transaction_id != @gc_ar_base_correct_dirty_tid
      @mutations_within_transactions.pop
    end
  end
  
  #def lock!(*meth, **am, &phetamine)
  #  super(*meth, **am, &phetamine)
  #  gc_ar_base_correct_dirty_restoration_time
  #end
  
end
