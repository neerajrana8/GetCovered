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

  belongs_to :organizable,
             polymorphic: true,
             required: false

  # has_many relationships
  has_many :histories,
           as: :recordable,
           class_name: 'History',
           foreign_key: :recordable_id
           
  has_many :assignments
  has_many :contact_records, as: :contactable
  # has_one relationships
  has_one :profile,
          as: :profileable,
          autosave: true

  accepts_nested_attributes_for :profile

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :email, type: :text
    end
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
