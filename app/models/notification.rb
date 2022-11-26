# == Schema Information
#
# Table name: notifications
#
#  id              :bigint           not null, primary key
#  subject         :string
#  message         :text
#  status          :integer          default("undelivered")
#  delivery_method :integer          default("push")
#  code            :integer          default("success")
#  action          :integer          default("community_rates_sync")
#  template        :integer          default("default")
#  notifiable_type :string
#  notifiable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Notification model
# file: app/models/notification.rb

class Notification < ApplicationRecord
  
  # Initialize Notification
  
  after_initialize  :initialize_notification

  # Send Notification
  # After Create, send notification by prefered notifiable method

  after_commit on: [:create] do 
    send_notification()
  end
  
  # Model recieving notification
  
  belongs_to :notifiable, polymorphic: true
  
  # Model generating notification
  
  belongs_to :eventable, polymorphic: true
  
  # Notification Status Enum
  # Provides options for notification lifecycle
  
  enum status: ["undelivered", "delivered", "read", "archived"]
  
  # Delivery Method Enum
  # Provides direction for how to deliver notification
  
  enum delivery_method: ["push", "mail"]
  
  # Code of Notification
  # Code of the event generating notification
  
  enum code: ["success", "warning", "error"]
  
  # Action
  # Action Generating Notification
  
  enum action: ["community_rates_sync", "import_success", "import_failure", "export_success", "export_failure",
                "policy_billing_failed", "policy_cancelled", "policy_30_days_remaining", "policy_renewed",
                "policy_accepted", "invoice_available", "invoice_payment_failed", "refund_failed",
                "invoice_payment_failed_after_proration", "new_policy_application", 
                "customer_accepted_policy_application"]
  
  # Template of Notification
  #
  # Sets html email template for notifications
  
  enum template: ["default", "invoice"], _prefix: :template
  
  # Active Scope
  #
  # Finds notifications that have been delivered or read
  
  scope :active, -> { where( status: ["delivered", "read"]) }

  
  # Validate presence of subject, message, status, delivery_method, code, and action             
  
  validates_presence_of :subject, :message, :status,
                        :delivery_method, :code# , 
#                         :action
  
  private
  
    def initialize_notification
      
      self.delivery_method ||= self.notifiable.nil? || self.action.nil? ? "push" : 
                                                                          self.notifiable.notification_options[self.action]

    end

    def send_notification
      if delivery_method == "push"
        update_column(:status, "delivered")  
      elsif delivery_method == "mail"
        if template == "invoice"
          InvoiceMailer.with(invoice: self.eventable)
                       .alert()
                       .deliver
        else
          SendEMailNotificationJob.perform_later(self)
        end
      end
    end
end
