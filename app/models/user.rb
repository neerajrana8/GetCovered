# frozen_string_literal: true

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  include RecordChange
  include DeviseTokenAuth::Concerns::User

  # Active Record Callbacks
  after_initialize :initialize_user

  has_many :authored_histories,
    as: :authorable,
    class_name: "History",
    foreign_key: :authorable_id

  has_many :histories,
    as: :recordable,
    class_name: "History",
    foreign_key: :recordable_id

  has_one :profile,
          as: :profileable,
          autosave: true

  accepts_nested_attributes_for :profile

  private

  def initialize_user
    # Blank for now...
  end
end
