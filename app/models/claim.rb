# Claim Model
# file: +app/models/claim.rb

class Claim < ApplicationRecord
  # Concerns
  include RecordChange, ElasticsearchSearchable
  
  # Active Record Callbacks
  after_initialize :initialize_claim
  
  # Relationships
  belongs_to :claimant, 
    polymorphic: true,
    required: true

  belongs_to :insurable

  belongs_to :policy

  has_many :histories,
    as: :recordable

  has_many_attached :documents

  # Validations
  validates_presence_of :subject, :description, :time_of_loss, :type_of_loss, :claimant
  
  validate :time_of_loss_cannot_be_in_future,
    unless: proc { |clm| clm.time_of_loss.nil? }

  validate :ownership_matches_up,
    unless: proc { |clm| clm.claimant.nil? }

  # Enum Options
  enum status: %i[submitted read completed rejected]

  enum type_of_loss: { OTHER: 0, FIRE: 1, WATER: 2, THEFT: 3 }

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :subject, type: :text, analyzer: 'english'
      indexes :description, type: :text, analyzer: 'english'
      indexes :claimant_type, type: :text, analyzer: 'english'
      indexes :time_of_loss, type: :date
    end
  end

  private
  
  def initialize_claim
    self.time_of_loss ||= Time.zone.today
    self.insurable = policy.insurables.take if policy.residential?
  end

  def time_of_loss_cannot_be_in_future
    errors.add(:time_of_loss, 'cannot be in future') if time_of_loss > Time.current
  end

  def ownership_matches_up
    # TODO: need to refactor
  end
end
