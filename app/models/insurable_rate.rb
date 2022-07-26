# == Schema Information
#
# Table name: insurable_rates
#
#  id              :bigint           not null, primary key
#  title           :string
#  schedule        :string
#  sub_schedule    :string
#  description     :text
#  liability_only  :boolean
#  number_insured  :integer
#  deductibles     :jsonb
#  coverage_limits :jsonb
#  interval        :integer          default("month")
#  premium         :integer          default(0)
#  activated       :boolean
#  activated_on    :date
#  deactivated_on  :date
#  paid_in_full    :boolean
#  carrier_id      :bigint
#  agency_id       :bigint
#  insurable_id    :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  enabled         :boolean          default(TRUE)
#  mandatory       :boolean          default(FALSE)
#
# InsurableRate model
# file: app/models/insurable_rate.rb
#
# Example:
#   >> @rate = InsurableRate.find(10)
#   >> @rate = InsurableRate.activated
#                  					.coverage_c
#                 				  .where("(coverage_limits ->> 'cov_c')::float = #{ "%.2f" % 15000.0 }")

class InsurableRate < ApplicationRecord
	
  after_initialize  :initialize_rate
  before_save :touch_activation_dates
  
  after_validation :set_description
              
  before_save :touch_split_premiums,
       if: Proc.new { |r| r.insurable.primary_address.state == "FL" }
	
	belongs_to :carrier
	belongs_to :agency
	belongs_to :insurable

  # Scopes
  scope :activated, -> { where(activated: true) }
  scope :deactivated, -> { where(activated: false) }
  scope :paid_in_full, -> { where(paid_in_full: true) }
  scope :on_payment_plan, -> { where(paid_in_full: false) }
  
  # Scopes for Rate Schedule
  scope :coverage_c, -> { where(schedule: "coverage_c") }
  scope :coverage_d, -> { where(schedule: "coverage_d") }
  scope :coverage_e, -> { where(schedule: "coverage_e") }
  scope :coverage_f, -> { where(schedule: "coverage_f") }

  scope :optional, -> { where(schedule: "optional") }
  scope :liability, -> { where(schedule: "liability") }
  scope :liability_only, -> { where(schedule: "liability_only") }
  
  # Scopes for Rate Schedule (Optional Schedule Only)
  scope :policy_fee, -> { where(sub_schedule: "policy_fee") }
  scope :earthquake_coverage, -> { where(sub_schedule: "earthquake_coverage") }
  
#   5.times do |i| 
#     
#     number_insured = i + 1
#     service = GetCoveredService.new()
#     scope_name = service.in_words(number_insured).downcase.gsub(' ', '_')
#     
#     scope "#{scope_name}_insured".to_sym, -> { where(number_insured: number_insured) }
#       
#   end
  
  enum interval: ["month", "quarter", "bi_annual", "annual"]

  private
  
    def initialize_rate
      self.schedule       ||= "coverage_c"
      self.number_insured ||= 1
      self.paid_in_full = false if self.paid_in_full.nil?
      self.liability_only = false if self.liability_only.nil?

      self.deductibles ||= {}
      self.deductibles["all_peril"] ||= "%.2f" % 0.00

      if !persisted? && 
         insurable.primary_address.state == "FL"
        self.deductibles["hurricane"] ||= "%.2f" % 0.00  
      end

      self.coverage_limits ||= {}
    end
    
    def touch_activation_dates
      unless activated.nil?
        
        self.activated_on = activated == true && 
                            activated_on.nil? ? Time.current : nil
        
        self.deactivated_on = activated == false && 
                              deactivated_on.nil? ? Time.current : nil
        
      end
    end

    def first_payment_coefficient
      0.163656 # = 0.2273 * 0.72
    end

    def period_premium
      unless premium.nil?
        case interval
          when "year"
            premium
          when "half_year"
            "%.2f" % (premium.to_f / 2.0)
          when "quarter_year"
            "%.2f" % (premium.to_f / 4.0)
          when "month"
            # down payment of first_payment_coefficient*premium plus 11 equal payments
            "%.2f" % (premium.to_f * (1.0 - first_payment_coefficient) / 11.0)
        end
      end
    end

    def first_payment_extra # WARNING: returns 0 for month because monthly_payment_tiers should be used instead
      case interval
        when "year"
          0.0
        when "half_year"
          premium.to_f - 2.0 * period_premium.to_f
        when "quarter_year"
          premium.to_f - 4.0 * period_premium.to_f
        when "month"
          0.0
      end
    end

    def monthly_payment_tiers
      first = ((premium.to_f * (1.0 - first_payment_coefficient) / 11.0) * 100.0).floor.to_i  # first = 11-time payments (standard 1st year payment)
      second = (premium.to_f * 100.0 / 12.0).floor.to_i - first                               # first + second = 12-time payments (standard 2nd+ year payment)
      third = (premium.to_f * 100.0).to_i - (first + second) * 12                             # first + second + third = 12-time payments + remainder (2nd+ year first payment)
      fourth = (premium.to_f * 100.0).to_i - 11 * first - (first + second + third)            # first + second + third = 11-time payments + remainder + first payment (1st year first payment)
      return([ first, second, third, fourth ])
    end
    
    
    def set_description
      unless persisted?
        
        for_florida = insurable.primary_address.state == "FL" ? true : false
        
        
        self.description = ""
        
        if self.schedule == "coverage_c"
          self.title = 'QBE Possessions Coverage'
          self.description.concat("QBE Possessions Coverage.")
          self.description.concat("$#{ "%.2f" % premium.to_f } Premium.  ")
          self.description.concat("#{ number_insured } Insured Individuals.  ")
          self.description.concat("$#{ "%.2f" % coverage_limits["cov_c"].to_f } Limit, ")
          if for_florida == true
            self.description.concat("$#{ "%.2f" % deductibles["all_peril"].to_f } Deductible, ")
            self.description.concat("$#{ "%.2f" % deductibles["hurricaine"].to_f } Hurricane.  ")
          else
            self.description.concat("$#{ "%.2f" % deductibles["all_peril"].to_f } Deductible.")
          end
        elsif self.schedule == "liability" ||
              self.schedule == "liability_only"
          self.title = "QBE #{self.schedule.titlecase} Coverage"
          self.description.concat("QBE #{ self.schedule.titlecase } Coverage.  ")
          self.description.concat("$#{ "%.2f" % premium.to_f } Premium.  ")
          self.description.concat("#{ number_insured } Insured Individuals.  ")
          unless coverage_limits["medical"].nil?
            self.description.concat("$#{ "%.2f" % coverage_limits["liability"] } Liability Limit, ")
            self.description.concat("$#{ "%.2f" % coverage_limits["medical"] } Medical Limit.")
          else
            self.description.concat("$#{ "%.2f" % coverage_limits["liability"] } Liability Limit.  ")
          end
        elsif self.schedule == "optional"
          self.title = self.sub_schedule.titlecase
          self.description.concat("QBE #{ self.sub_schedule.titlecase } Coverage.  ")
          self.description.concat("$#{ "%.2f" % premium.to_f } Premium.  ")
          self.description.concat("#{ number_insured } Insured Individuals.  ")
          self.description.concat("$#{ "%.2f" % coverage_limits["cov_c"].to_f } Limit, ")
          if for_florida == true
            self.description.concat("$#{ "%.2f" % deductibles["all_peril"].to_f } Deductible, ")
            self.description.concat("$#{ "%.2f" % deductibles["hurricaine"].to_f } Hurricane.  ")
          else
            self.description.concat("$#{ "%.2f" % deductibles["all_peril"].to_f } Deductible.")
          end
        end
        
      end
    end
    
    def touch_split_premiums
      
      # Split Premiums
        
    end  	
end
