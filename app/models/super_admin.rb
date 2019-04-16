# frozen_string_literal: true

class SuperAdmin < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  include DeviseTokenAuth::Concerns::User

  # belongs_to relationships

  # has_many relationships

  # has_one relationships
  has_one :profile,
          as: :profileable,
          autosave: true

  accepts_nested_attributes_for :profile
end
