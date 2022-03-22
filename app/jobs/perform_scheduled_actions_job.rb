class PerformScheduledActionsJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    ScheduledAction.where(status: 'pending')
                   .where("trigger_time <= ?", Time.current)
                   .order(trigger_time: :asc)
                   .each do |action|
      action.perform!
    end
  end
  
end
