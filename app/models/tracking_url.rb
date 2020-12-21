# frozen_string_literal: true

class TrackingUrl < ApplicationRecord
  has_many :leads

  belongs_to :agency
  validate :one_attribute_presence, on: [:create, :update]
  validates_presence_of :landing_page, :agency

  scope :not_deleted, -> { where(deleted: false) }

  def branding_url
    "https://#{self.agency.branding_profiles.last.url}"
  end

  def form_url
    "#{branding_url}/#{self.landing_page}"
  end

  private

  def one_attribute_presence
    errors.add(:tracking_url, 'must have at least one attribute presented') unless self.campaign_source.present? || self.campaign_medium.present? || self.campaign_name.present?
  end

end

