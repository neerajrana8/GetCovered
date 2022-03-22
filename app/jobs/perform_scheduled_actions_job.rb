class PerformScheduledActionsJob < ApplicationJob
  queue_as :default
  
  class ScheduledActionError < StandardError
    def initialize(msg)
      super(msg)
    end
  end

  def perform(*_args)
    errored = []
    ScheduledAction.where(status: 'pending')
                   .where("trigger_time <= ?", Time.current)
                   .order(trigger_time: :asc)
                   .each do |action|
      action.perform! rescue errored.push(action)
    end
    unless errored.blank?
      raise ScheduledActionError.new("Errors encountered during PerformScheduledActionsJob; errored records by action: #{errored.group_by{|sa| sa.action }.transform_values{|v| v.map{|vv| vv.id } }.to_s}")
    end
  end
  
end
