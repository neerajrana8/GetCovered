# DirtyTransactionTracker
# adds some dirty-method-like tracking for changes within a transaction




module DirtyTransactionTracker
  extend ActiveSupport::Concern

  included do
    
    def saved_change_to_attribute_within_transaction?(attr_name, **options)
      mutations_within_transaction.changed?(attr_name, **options)
    end
    
    def previous_changes_within_transaction
      @previously_changed_within_transaction ||= ActiveSupport::HashWithIndifferentAccess.new
      @previously_changed_within_transaction.merge(mutations_within_transaction.changes)
    end
    
    before_save :dtt___before_transaction
    after_save :dtt___for_transaction
    after_commit :dtt___after_transaction
    after_rollback :dtt___after_transaction
    
    private
	  
      def mutations_within_transaction
        @mutations_within_transactions&.last || ActiveModel::NullMutationTracker.instance
      end
      
      def dtt___before_transaction
        if ApplicationRecord.transaction_id != @dtt___tid
          @dtt___tid = ApplicationRecord.transaction_id
          (@mutations_within_transactions ||= []).push(ActiveModel::AttributeMutationTracker.new(self.instance_variable_get(:@attributes)))
        end
      end
      
      def dtt___apply_changes
        lord_of_mutants = @mutations_within_transactions.last
        self.previous_changes.each do |field, changez|
          if lord_of_mutants.send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
            lord_of_mutants.send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
          end
          lord_of_mutants.send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
          lord_of_mutants.send(:attributes)[field].instance_variable_set(:@value, changez[1])
        end
      end
      
      def dtt___for_transaction
        dtt___apply_changes
      end
      
      def dtt___after_transaction
        if ApplicationRecord.transaction_id != @dtt___tid
          @mutations_within_transactions.pop
        end
      end
      
  end
end
