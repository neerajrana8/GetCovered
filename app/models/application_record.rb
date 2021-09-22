class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  
  # below is a fix for:
  #  1) The AR bug where locking a record destroys its previous_changes dirty data, and
  #  2) The AR design oversight where previous_changes isn't cumulative within a transaction (and thus after_commit can't determine what was changed over the course of a transaction)
  
  after_save :gc_ar_base_correct_dirty_for_transaction
  after_commit :gc_ar_base_correct_dirty_after_transaction
  after_rollback :gc_ar_base_correct_dirty_after_transaction
  
  def gc_ar_base_correct_dirty_for_transaction
    puts "PRESERVING DIRTY INFO"
    @gc_ar_base_correct_dirty_mbls ||= {}
    self.previous_changes.each do |field, changez|
      # correct field history in our internal moosehopper
      if @gc_ar_base_correct_dirty_mbls.has_key?(field)
        @gc_ar_base_correct_dirty_mbls[field][1] = changez[1]
      else
        @gc_ar_base_correct_dirty_mbls[field] = [changez[0], changez[1]]
      end
    end
    gc_ar_base_correct_dirty_restoration_time
  end
  
  def gc_ar_base_correct_dirty_restoration_time
    if @gc_ar_base_correct_dirty_mbls
    
      # THIS IS A BETTER WAY OF DOING IT -- but setting @attributes this way doesn't solve our problem. We need to make a proper mutationtracker when mutations_before_last_save is a NullMutationTracker. And I don't know how yet. Workaround below.
      #@attributes = ActiveModel::AttributeSet.new({}) if self.send(:mutations_before_last_save).class == ActiveModel::NullMutationTracker
      #@gc_ar_base_correct_dirty_mbls.each do |field, changez|
      #  if self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
      #    self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
      #  end
      #  self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value_before_type_cast, changez[0])
      #  self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_get(:@original_attribute).instance_variable_set(:@value, changez[0])
      #  self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
      #  self.send(:mutations_before_last_save).send(:attributes)[field].instance_variable_set(:@value, changez[1])
      #end
      
      @gc_ar_base_correct_dirty_mbls.each do |field, changez|
        if self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute).nil?
          self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@original_attribute, self.send(:mutations_from_database).send(:attributes)[field].dup)
        end
        self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute)&.instance_variable_set(:@value_before_type_cast, changez[0])
        self.send(:mutations_from_database).send(:attributes)[field].instance_variable_get(:@original_attribute)&.instance_variable_set(:@value, changez[0])
        self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@value_before_type_cast, changez[1])
        self.send(:mutations_from_database).send(:attributes)[field].instance_variable_set(:@value, changez[1])
      end
      self.send(:changes_applied)
      
    end
  end
  
  def gc_ar_base_correct_dirty_after_transaction
    @gc_ar_base_correct_dirty_mbls = nil
  end
  
  def lock!(*largs, **kargs, &barg)
    super(*largs, **kargs, &barg)
    gc_ar_base_correct_dirty_restoration_time
  end
  
  
  
end
