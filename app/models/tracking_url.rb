# frozen_string_literal: true

class TrackingUrl < ApplicationRecord
  has_many :leads

  belongs_to :agency
  validates_presence_of :landing_page, :campaign_source,
                        :campaign_medium, :campaign_name, :agency

  scope :not_deleted, -> { where(deleted: false) }

end

