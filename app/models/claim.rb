# Claim Model
# file: +app/models/claim.rb

class Claim < ApplicationRecord
  # Concerns
  include RecordChange, ElasticsearchSearchable
  
  # Active Record Callbacks
  after_initialize  :initialize_claim
  
      # Relationships
  belongs_to :claimant, 
    polymorphic: true,
    required: true

  belongs_to :insurable

  belongs_to :policy

  has_many :histories,
    as: :recordable

    # Validations
  validates_presence_of :subject, :description, :time_of_loss, :claimant
  
  validate :time_of_loss_cannot_be_in_future,
    unless: Proc.new { |clm| clm.time_of_loss.nil? }

  validate :ownership_matches_up,
    unless: Proc.new { |clm| clm.claimant.nil? }

  # Enum Options
  enum status: [:submitted, :read, :completed, :rejected]
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :subject, analyzer: 'english'
      indexes :description, analyzer: 'english'
      indexes :claimant_type, analyzer: 'english'
      indexes :time_of_loss, type: 'date'
    end
  end

  private
  
    def initialize_claim
      self.time_of_loss ||= Time.zone.today
    end

    def time_of_loss_cannot_be_in_future
      if time_of_loss > Time.current
        errors.add(:time_of_loss, "cannot be in future")  
      end
    end

    def ownership_matches_up
      # TODO need to refactor
    end
end

