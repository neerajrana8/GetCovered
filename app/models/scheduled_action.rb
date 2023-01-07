# == Schema Information
#
# Table name: scheduled_actions
#
#  id              :bigint           not null, primary key
#  action          :integer          not null
#  status          :integer          default("pending"), not null
#  trigger_time    :datetime         not null
#  input           :jsonb
#  output          :jsonb
#  error_messages  :string           default([]), not null, is an Array
#  started_at      :datetime
#  ended_at        :datetime
#  actionable_type :string
#  actionable_id   :bigint
#  parent_id       :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  #prerequisite_ids :bigint          default([]), not null, is an Array

class ScheduledAction < ApplicationRecord
  #include ScheduledActionUserConsolidation
  
  belongs_to :actionable,
    polymorphic: true,
    optional: true
  belongs_to :parent,
    class_name: 'ScheduledAction',
    foreign_key: :parent_id,
    optional: true
    
  before_save :set_started_at, if: Proc.new{|sa| sa.will_save_change_to_attribute?('status') && sa.status == 'executing' && !sa.will_save_change_to_attribute?('started_at') }
  before_save :set_ended_at, if: Proc.new{|sa| sa.will_save_change_to_attribute?('status') && sa.attribute_change_to_be_saved('status').first == 'executing' && !sa.will_save_change_to_attribute?('ended_at') }
  
  enum status: {
    pending: 0, # WARNING: leave pending as 0. The database defaults to this value.
    executing: 1,
    cancelled: 2,
    complete: 3,
    errored: 4
  }
  
  enum action: { # WARNING: define a method called perform_#{self.action} when you add an action here
    scheduled_action_test: 0,
    error_handling_test: 1,
    user_consolidation: 2
  }
  
  def prerequisites
    #ScheduledAction.where(id: self.prerequisite_ids)
  end
  
  def perform!
    # set to executing
    self.with_lock do
      return "Status is '#{self.status}', but must be 'pending' or 'errored' to perform!" unless self.status == 'pending' || self.status == 'errored'
      #return "Some prerequisites have not yet been completed!" unless self.prerequisites.where.not(status: 'complete').blank?
      self.update(status: 'executing')
    end
    # perform the action
    begin
      self.send("perform_#{self.action}")
    rescue => ex
      # log the error and re-raise
      self.status = 'errored'
      self.error_messages.push("#{Time.current.to_date.to_s}: Uncaught exception thrown by ScheduledAction perform call. #{ex.class.name}: #{ex.respond_to?(:message) ? ex.message : "(no error message)"}")
      unless self.save
        self.error_messages.push("#{Time.current.to_date.to_s}: Unable to save error messages after uncaught exception (resorted to update_columns). Model error hash: #{self.errors.to_h}")
        self.update_columns(status: self.status, error_messages: self.error_messages, ended_at: Time.current)
      end
      raise
    end
    # mark ourselves finished if the performance logic didn't do it; save ourselves in case performance logic set some properties
    self.status = 'complete' if self.status == 'executing'
    self.save
  end
  
  
  private
  
    def set_started_at
      self.started_at = Time.current
    end
    
    def set_ended_at
      self.ended_at = Time.current
    end
    
    def perform_scheduled_action_test
      self.output = { 'success' => true }
    end
  
    def perform_error_handling_test
      goose = 3 / 0
    end
    
end
