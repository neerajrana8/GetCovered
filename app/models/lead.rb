class Lead < ApplicationRecord

  include ElasticsearchSearchable

  belongs_to :user, optional: true
  belongs_to :tracking_url, optional: true
  belongs_to :agency, optional: true

  has_one :profile, as: :profileable
  has_one :address, as: :addressable

  has_many :lead_events, dependent: :destroy

  accepts_nested_attributes_for :address, :profile, update_only: true

  enum status: %i[prospect return converted lost]

  before_create :set_identifier
  before_save :set_status

  private

  def set_identifier
    self.identifier = Digest::MD5.hexdigest(fields_for_identifier) if self.identifier.blank?
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
