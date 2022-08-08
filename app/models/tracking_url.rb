# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_urls
#
#  id                  :bigint           not null, primary key
#  landing_page        :string
#  campaign_source     :string
#  campaign_medium     :string
#  campaign_term       :string
#  campaign_content    :text
#  campaign_name       :string
#  deleted             :boolean          default(FALSE)
#  agency_id           :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  branding_profile_id :integer
#
class TrackingUrl < ApplicationRecord
  has_many :leads

  belongs_to :agency
  belongs_to :branding_profile, optional: true

  validates_presence_of :landing_page, :agency, :campaign_name

  scope :not_deleted, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }

  def branding_url
    "https://#{branding_profile&.url || agency.branding_profiles.first.url}"
  end

  def form_url
    "#{branding_url}/#{self.landing_page}"
  end
end
