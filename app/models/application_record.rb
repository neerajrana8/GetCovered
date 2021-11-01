
  
# below is a fix for the AR bug where locking a record destroys its previous_changes dirty data;
# there is also code to enable the differentiation of the current top-level transaction via ApplicationRecord.transaction_id, which is used in the DirtyTransactionTracker model concern
  
  

# hideous monkey patch
module ActiveRecord
  GC_MONKEY_HAS_RUN_WILD = true

  module ConnectionAdapters
    module DatabaseStatements
      alias :gc_active_record_transaction :transaction
    
      def transaction(*largs, **kargs, &barg)
        ApplicationRecord.increment_transaction_id if ActiveRecord::Base.connection.open_transactions == 0
        gc_active_record_transaction(*largs, **kargs, &barg)
      end
    end
  end
end unless ActiveRecord.const_defined?('GC_MONKEY_HAS_RUN_WILD')


class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  def self.transaction_id
    connection.open_transactions == 0 ? nil : @gc_ar_base_correct_dirty_transaction_id
  end
  
  def self.increment_transaction_id
    @gc_ar_base_correct_dirty_mask ||= 2**64 - 1
    @gc_ar_base_correct_dirty_transaction_id ||= 0
    @gc_ar_base_correct_dirty_transaction_id = (@gc_ar_base_correct_dirty_transaction_id + 1) & @gc_ar_base_correct_dirty_mask
  end

  def lock!(*rabbits, **play, &in_the_woods)
    rescued_from_oblivion = self.instance_variable_get(:@mutations_before_last_save)
    to_return = super(*rabbits, **play, &in_the_woods)
    self.instance_variable_set(:@mutations_before_last_save, rescued_from_oblivion)
    to_return
  end
  
end
