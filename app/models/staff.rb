# frozen_string_literal: true

class Staff < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  include SetAsOwner
  include RecordChange
  include DeviseTokenAuth::Concerns::User

  enum role: { staff: 0, agent: 1, owner: 2, super_admin: 3 }
  # Active Record Callbacks
  after_initialize :initialize_staff

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

  # has_one relationships
  has_one :profile,
          as: :profileable,
          autosave: true

  accepts_nested_attributes_for :profile

  private

  def initialize_staff
  end
end
