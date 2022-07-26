# == Schema Information
#
# Table name: claims
#
#  id            :bigint           not null, primary key
#  subject       :string
#  description   :text
#  time_of_loss  :datetime
#  status        :integer          default("pending")
#  claimant_type :string
#  claimant_id   :bigint
#  insurable_id  :bigint
#  policy_id     :bigint
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  type_of_loss  :integer          default("OTHER"), not null
#  staff_notes   :text
#
# Claim Model
# file: +app/models/claim.rb

class Claim < ApplicationRecord
  # Concerns
  include RecordChange

  # Active Record Callbacks
  after_initialize :initialize_claim
  after_create_commit :notify_support

  # Relationships
  belongs_to :claimant,
             polymorphic: true

  belongs_to :insurable, optional: true

  belongs_to :policy, touch: true

  has_many :histories,
           as: :recordable

  has_many_attached :documents

  # Validations
  validates_presence_of :subject, :description, :time_of_loss, :type_of_loss

  validate :policy_of_claimant

  validate :time_of_loss_cannot_be_in_future,
    unless: proc { |clm| clm.time_of_loss.nil? }

  validate :ownership_matches_up, unless: proc { |clm| clm.claimant.nil? }

  validate :correct_document_mime_type

  # Enum Options
  enum status: %i[pending approved declined]

  enum type_of_loss: { OTHER: 0, FIRE: 1, WATER: 2, THEFT: 3 }

  def claimant_full_name
    claimant&.profile&.full_name
  end

  private

  def initialize_claim
    self.time_of_loss ||= Time.zone.today
    self.insurable    = policy.insurables.take if policy && policy.residential?
  end

  def time_of_loss_cannot_be_in_future
    errors.add(:time_of_loss, 'cannot be in future') if time_of_loss > Time.current
  end

  def correct_document_mime_type
    documents.each do |document|
      unless document.blob.content_type.starts_with?(
        'image/png', 'image/jpeg', 'image/jpg', 'image/svg',
        'image/gif', 'application/pdf', 'text/plain', 'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/comma-separated-values', 'application/vnd.ms-excel'
      )
        errors.add(:documents, 'The document wrong format, only: PDF, DOC, DOCX, XLSX, XLS, CSV, JPG, JPEG, PNG, GIF, SVG, TXT')
      end
    end
  end

  def ownership_matches_up
    # TODO: need to refactor
  end

  def policy_of_claimant
    policies_ids = []
    if claimant.is_a?(Staff)
      return if claimant.role == 'super_admin'
      policies_ids = claimant.organizable.policies.ids
    elsif claimant.is_a? User
      policies_ids = claimant.policies.ids
    end
    errors.add(:policy_id, "Policy is not included in claimant's scope") unless policies_ids.include?(policy_id)
  end

  def notify_support
    InternalMailer.with(organization: Agency.find(1)).claim_notification(claim: self).deliver_now
  end
end
