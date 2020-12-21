class Lead < ApplicationRecord

  #TODO: move to config file
  PAGES_RENT_GUARANTEE = ['Landing Page', 'Eligibility Page', 'Basic Info Page', 'Eligibility Requirements Page', 'Address Page', 'Employer Page',
           'Landlord Page', 'Confirmation Page', 'Terms&Conditions Page', 'Payment Page']

  PAGES_RESIDENTIAL = ['Basic Info Section', 'Insurance Info Section', 'Coverage Limits Section', 'Insured Details Section', 'Payment Section']

  belongs_to :user, optional: true
  belongs_to :tracking_url, optional: true
  belongs_to :agency, optional: true

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
  scope :prospected, -> { where(status: 'prospect')}
  scope :archived, -> { where(status: 'archived')}
  scope :with_user, -> { where.not(user_id: nil) }

  def self.date_of_first_lead
    Lead.pluck(:last_visit).select(&:present?).sort.first
  end

  def self.presented
    columns_distinct = [:email]
    distinct_ids = Lead.select("MAX(id) as id").group(columns_distinct).map(&:id)
    Lead.where.not(email: [nil, '']).where(id: distinct_ids)
  end

  def check_identifier
    set_identifier
  end

  def last_event
    self.lead_events.try(:last)
  end

  #TODO: need to be updated according new pages
  def page_further?(current_page)
    pages = self.last_event.policy_type.rent_guarantee? ? PAGES_RENT_GUARANTEE : PAGES_RESIDENTIAL
    pages.index(current_page) > (pages.index(self.last_visited_page) || 0)
  end

  private

  def set_identifier
    new_uid = Digest::MD5.hexdigest(fields_for_identifier)
    old_uid = self.identifier
    self.identifier = new_uid if identifier.nil? && new_uid != old_uid
  end

  #can be extended if needed, but need to be sure about old ones
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

end
