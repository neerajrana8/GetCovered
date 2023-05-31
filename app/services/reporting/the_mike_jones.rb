module Reporting
  class TheMikeJones < ApplicationService

    attr_accessor :date_range
    attr_accessor :options

    def initialize(date_range, options)
      @date_range = date_range
      @options = { :all => false }
      @options.merge!(options) unless options.nil?
    end

    def call
      raise "Range null" if @date_range.nil? && @options[:all] == false

      @report = Array.new
      @report << report_headers()
      Policy.where(query()).find_each do |policy|
        transaction = %w(RENEWED CANCELLED).include?(policy.status) ? policy.status : 'NEW BUSINESS'
        term_effective_date = policy.status == 'RENEWED' ? policy.last_renewed_on : policy.effective_date
        is_sub_agency = policy.agency.agency_id.nil? ? false : true
        premium = policy.policy_premiums.first
        row = [policy.id,
               policy.number,
               policy.carrier.title,
               policy.created_at.strftime('%B %d, %Y'),
               policy.effective_date.strftime('%B %d, %Y'),
               term_effective_date.strftime('%B %d, %Y'),
               policy.last_renewed_on.nil? ? nil : policy.last_renewed_on.strftime('%B %d, %Y'),
               policy.cancellation_date.nil? ? nil : policy.cancellation_date.strftime('%B %d, %Y'),
               policy.primary_insurable&.parent_community&.account&.title,
               is_sub_agency ? policy.agency.title : nil,
               is_sub_agency ? policy.agency.agency.title : policy.agency.title,
               policy.primary_insurable&.parent_community&.title,
               policy&.primary_user&.profile&.full_name,
               'HO4',
               transaction,
               premium.nil? ? 'ERROR' : sprintf("%.2f", (premium.total_premium.to_f / 100)),
               premium.nil? ? 'ERROR' : sprintf("%.2f", (premium.total.to_f / 100)),
               premium.nil? ? 'ERROR' : sprintf("%.2f", (premium.total_fee - premium.total_hidden_fee).to_f / 100)]
        @report << row
      end

      return @report
    end

    private

    def query
      base_query = { :policy_type_id => 1, :policy_in_system => true }
      base_query[:created_at] = @date_range unless @options[:all]
      return base_query
    end

    def report_headers
      return ['Policy ID',
              'Policy Number',
              'Carrier',
              'Policy Created',
              'Original Effective Date',
              'Current Term Effective Date',
              'Last Renewed On',
              'Cancelled On',
              'Account',
              'Sub Agency',
              'Agency',
              'Community',
              'Policy Holder',
              'Policy Type',
              'Transaction Type',
              'Net Premium',
              'Gross Premium',
              'Get Covered Fees']
    end
  end
end