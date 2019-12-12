# frozen_string_literal: true

class Staff < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  serialize :tokens
  
  include SetAsOwner
  include RecordChange
  include DeviseTokenAuth::Concerns::User
  include ElasticsearchSearchable

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3 }
  # Active Record Callbacks
  after_initialize :initialize_staff
  after_create :set_first_as_primary_on_organizable

  # belongs_to relationships
  # belongs_to :account, required: true

  belongs_to :organizable, polymorphic: true, required: false

  # has_many relationships
  has_many :histories,
           as: :recordable,
           class_name: 'History',
           foreign_key: :recordable_id
           
  has_many :assignments

  # has_one relationships
  has_one :profile,
          as: :profileable,
          autosave: true

  has_many :reports, as: :reportable

  accepts_nested_attributes_for :profile

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :email, type: :text
      indexes :profile do
        indexes :id,   type: :long
        indexes :first_name, type: :text
        indexes :last_name, type: :text
        indexes :middle_name, type: :text
        indexes :title, type: :text
        indexes :suffix, type: :text
        indexes :full_name, type: :text
        indexes :contact_email, type: :text
        indexes :contact_phone, type: :text
      end
    end
  end

  def as_indexed_json(options = {})
    self.as_json(
      options.merge(
        only: [:id, :email, :organizable_type, :organizable_id, :role, :created_at, :updated_at],
        include: :profile
      )
    )
  end

  def self.update_profile(profile, options = {})
    options[:index] ||= index_name
    options[:type]  ||= document_type
    options[:wait_for_completion] ||= false

    options[:body] = {
      conflicts: :proceed,
      query: {
        match: {
          'profile.id': profile.id
        }
      },
      script: {
        lang:   :painless,
        source: "ctx._source.profile.contact_phone = params.profile.contact_phone; ctx._source.profile.last_name = params.profile.last_name; ctx._source.profile.first_name = params.profile.first_name; ctx._source.profile.full_name = params.profile.full_name; ctx._source.profile.title = params.profile.title; ctx._source.profile.contact_email = params.profile.contact_email;",
        params: { profile: { contact_phone: profile.contact_phone, last_name: profile.last_name, first_name: profile.first_name, full_name: profile.full_name, title: profile.title, contact_email: profile.contact_email } }
      }
    }

    __elasticsearch__.client.update_by_query(options)
  end


  # Override as_json to always include profile information
  def as_json(options = {})
    json = super(options.reverse_merge(include: :profile))
    json
  end


  private

	  def initialize_staff
	  end

		def set_first_as_primary_on_organizable
			unless organizable.nil?
				self.organizable.update staff_id: id if organizable.staff.count == 1
			end	
		end
end
