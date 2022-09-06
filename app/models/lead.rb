# == Schema Information
#
# Table name: leads
#
#  id                  :bigint           not null, primary key
#  email               :string
#  identifier          :string
#  user_id             :bigint
#  labels              :string           is an Array
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  status              :integer          default("prospect")
#  last_visit          :datetime
#  last_visited_page   :string
#  tracking_url_id     :integer
#  agency_id           :integer
#  archived            :boolean          default(FALSE)
#  account_id          :integer
#  branding_profile_id :integer
#
class Lead < ApplicationRecord

  include Filterable
  include RecordChange


  #TODO: move to config file
  PAGES_RENT_GUARANTEE = ['Landing Page', 'Eligibility Page', 'Basic Info Page', 'Eligibility Requirements Page', 'Address Page', 'Employer Page',
           'Landlord Page', 'Confirmation Page', 'Terms&Conditions Page', 'Payment Page']

  PAGES_RESIDENTIAL = ['Basic Info Section', 'Insurance Info Section', 'Coverage Limits Section', 'Insured Details Section', 'Payment Section']

  PAGES_DEPOSIT_CHOICE = ['Deposit Basic Info Section', 'Deposit Bond Section', 'Deposit Additional occupants', 'Payment Deposit Section']

  belongs_to :user, optional: true
  belongs_to :tracking_url, optional: true
  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :branding_profile, optional: true

  has_one :profile, as: :profileable
  has_one :address, as: :addressable

  has_many :lead_events, dependent: :destroy
  has_many :histories, as: :recordable

  accepts_nested_attributes_for :address, :profile, update_only: true

  enum status: %i[prospect return converted lost archived]

  before_create :set_identifier, if: -> { identifier.blank? }
  before_save :set_status

  validates :email, presence: true

  scope :converted, -> { where(status: 'converted')}
  scope :not_converted, -> { where.not(status: 'converted') }
  scope :prospected, -> { where(status: 'prospect')}
  scope :archived, -> { where(archived: true)}
  scope :not_archived, -> { where(archived: false)}
  scope :with_user, -> { where.not(user_id: nil) }

  scope :by_last_visit, ->(start_date, end_date) {
    where(last_visit: start_date..end_date)
  }

  scope :group_trunc_day_by_last_visit, ->(trunc_by = 'day') {
    group("DATE_TRUNC('#{trunc_by}', last_visit)::date")
  }

  scope :grouped_by_last_visit, ->(trunc_by = 'day') {
    select(Arel.sql("date_trunc('#{trunc_by}', last_visit)::date as last_visit, #{STATUS_CASE_SQL}")).
      group_trunc_day_by_last_visit(trunc_by)
  }

  scope :actual, -> {
    where(archived: false)
  }

  scope :archived, -> {
    where(archived: true)
  }

  scope :presented, -> {
    where.not(email: [nil, ''])
  }

  scope :by_agency, ->(agency_id) { where(agency_id: agency_id) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_branding_profile, ->(branding_profile_id) { where(branding_profile_id: branding_profile_id) }


  scope :join_last_events, ->(policy_type_id = nil){
    sql = "(#{JOIN_LATEST_EVENT_SQL}"
    sql += " WHERE policy_type_id IN (#{policy_type_id.join(',')})" unless policy_type_id.nil?
    sql += ') AS leads'
    from(sql)
  }

  JOIN_LATEST_EVENT_SQL = <<-SQL.freeze
    SELECT l.*, lead_event.policy_type_id, lead_event.data, policy_type_id, title FROM leads as l JOIN (
          SELECT * FROM lead_events le WHERE id IN (
            SELECT MAX(id) FROM lead_events le2 GROUP BY lead_id
          )
        ) AS lead_event
        ON l.id = lead_event.lead_id
        LEFT JOIN policy_types pt ON pt.id = policy_type_id
  SQL

  scope :grouped_by_date, ->(trunc_by) {
    sql = Arel.sql("date_trunc('#{trunc_by}', last_visit)::date as last_visit, #{STATUS_CASE_SQL}")
    sql += ", SUM(json_extract_path_text(lead_events_timeseries, TO_CHAR(last_visit, 'YYYY-MM-DD'))::int) as site_visitors "
    select(sql).group_trunc_day_by_last_visit(trunc_by)
  }


  # TODO: Rewrite to Arel.SQL
  STATUS_CASE_SQL = <<-SQL.freeze
        SUM(CASE WHEN status != -1 then 1 else 0 end) AS visits,
        SUM(CASE WHEN status = 0 then 1 else 0 end) AS prospected,
        SUM(CASE WHEN status = 1 then 1 else 0 end) AS returned,
        SUM(CASE WHEN status = 2 then 1 else 0 end) AS converted,
        SUM(CASE WHEN status != 2 then 1 else 0 end) AS not_converted,
        SUM(CASE WHEN status = 3 then 1 else 0 end) AS lost,
        SUM(CASE WHEN status = 4 then 1 else 0 end) AS archived,
        SUM(CASE WHEN (status != 4 AND last_visited_page IN ('Payment Page', 'Payment Section')) then 1 else 0 end)
        AS not_finished_applications,
        SUM(CASE WHEN (status != 4 AND last_visited_page NOT IN ('Landing Page', 'Basic info Section')) then 1 else 0 end)
        AS applications,
        SUM(CASE WHEN (status = 2 OR status = 0) then 1 else 0 end) AS visitors
  SQL

  def self.get_stats(range, agency_id, branding_profile_id, account_id, leads_ids)
    sql = "SELECT #{STATUS_CASE_SQL} FROM leads"
    sql += ' WHERE '
    sql += '  archived = False'
    sql += " AND (email != '' OR email IS NOT NULL)"
    sql += " AND agency_id IN (#{agency_id.join(',')})" unless agency_id.nil?
    sql += " AND branding_profile_id IN (#{branding_profile_id.join(',')})" unless branding_profile_id.nil?
    sql += " AND account_id IN (#{account_id.join(',')})" unless account_id.nil?
    sql += " AND id IN (#{leads_ids.join(',')})" unless leads_ids.count.zero?

    record = ActiveRecord::Base.connection.execute(sql)
    record.first unless record.first.values.compact.empty?
  end

  def self.date_of_first_lead
    Lead.pluck(:last_visit).select(&:present?).sort.first
  end

  def self.presented
    Lead.where.not(email: [nil, ''])
  end

  def check_identifier
    set_identifier
  end

  def last_event
    self.lead_events.try(:last)
  end

  #TODO: need to be updated according new pages
  def page_further?(current_page)
    pages = if self.last_event.policy_type.rent_guarantee?
              PAGES_RENT_GUARANTEE
            elsif self.last_event.policy_type.residential?
              PAGES_RESIDENTIAL
            else
              PAGES_DEPOSIT_CHOICE
            end
    pages.index(current_page) > (pages.index(self.last_visited_page) || 0)
  end

  def first_name
    self&.profile.first_name
  end

  def last_name
    self&.profile.last_name
  end

  def policy_type
    self.lead_events&.last&.policy_type&.title
  end

  def premium_total
    self&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.total
  end

  def billing_strategy
    self&.user&.policy_applications&.last&.policy_quotes&.last&.policy_premium&.billing_strategy&.title
  end

  def campaign_name
    self&.tracking_url&.campaign_name
  end

  private

  # DO NOT CHANGE! CAN BRAKE IDENTIFIERS UNIQUENESS
  def set_identifier
    new_uid = Digest::MD5.hexdigest(fields_for_identifier)
    old_uid = self.identifier
    self.identifier = new_uid if identifier.nil? && new_uid != old_uid
  end

  # can be extended if needed, but need to be sure about old ones
  def fields_for_identifier
    "#{self.email}"
  end

  def set_status
    #if User.find_by(unconfirmed_email: self.email) || User.find_by(email: self.email)
    #  self.status = 2
    #end

    #tbd
    # prospect: first time visitor
    #
    # return: repeat visitor
    #
    # converted: converted to user
    #
    # lost: no return visit in 90 days
  end

  def self.to_csv(filters = nil)
    attributes =
        {"Agency" => "agency_id", "Email" => "email", "First Name" => "first_name","Last Name" => "last_name",
     "Date Created" => "created_at", "Last Activity" => "last_visit", "Policy Type" => "policy_type",
     "Last Visited Page" => "last_visited_page", "Premium Total" => "premium_total",
     "Billing Strategy"=>"billing_strategy", "Campaign Name"=>"campaign_name"
    }

    CSV.generate(headers: true) do |csv|
      if filters.present?
        csv << ['Filters']
        csv << ['Archived', filters[:filter][:archived]]
        csv << ['Agency', Agency.find(filters[:filter][:agency_id])&.title] if filters[:filter][:agency_id]
        csv << ['Policy Type', PolicyType.find(filters[:filter][:lead_events][:policy_type_id])&.title] if filters[:filter][:lead_events]
        csv << ['Last Visit Period', filters[:filter][:last_visit][:start], filters[:filter][:last_visit][:end] ] if filters[:filter][:last_visit]
        if filters[:filter][:tracking_url]
          csv << ['Campaign Name', filters[:filter][:tracking_url][:campaign_name]]
          csv << ['Campaign Medium', filters[:filter][:tracking_url][:campaign_medium]]
          csv << ['Campaign Source', filters[:filter][:tracking_url][:campaign_source]]
        end
      end

      csv << attributes.keys

      all.each do |lead|
        csv << attributes.values.map{ |attr| lead.send(attr) }
      end
    end
  end
end
