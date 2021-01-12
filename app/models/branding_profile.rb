##
# =Branding Profile Model
# file: +app/models/branding_profile.rb+

class BrandingProfile < ApplicationRecord

  after_initialize :initialize_branding_profile
  before_save :sanitize_branding_url
  after_save :check_default
  after_save :check_global_default
  after_create :set_up_from_master

  validates_presence_of :url

  belongs_to :profileable, polymorphic: true

  has_many :branding_profile_attributes, dependent: :destroy
  has_many :pages, dependent: :destroy
  has_many :faqs, dependent: :destroy

  has_many_attached :images

  scope :default, -> { where(default: true) }

  accepts_nested_attributes_for :branding_profile_attributes
  accepts_nested_attributes_for :faqs
  accepts_nested_attributes_for :pages

  def self.global_default
    BrandingProfile.find_by(global_default: true)
  end

  def contact_email
    branding_profile_attributes.find_by_name('contact_email')&.value
  end

  private

  def initialize_branding_profile
    self.styles ||= {}
    # Admin Styles Options
    self.styles['admin'] ||= {}
    self.styles['admin']['colors'] ||= {}
    self.styles['admin']['colors']['primary']   ||= '#000000'
    self.styles['admin']['colors']['highlight'] ||= '#FFFFFF'
    self.styles['admin']['colors']['warning']   ||= '#FF0000'
    self.styles['admin']['content'] ||= {}
    # Client Styles Options
    self.styles['client'] ||= {}
    self.styles['client']['colors'] ||= {}
    self.styles['client']['colors']['primary']   ||= '#000000'
    self.styles['client']['colors']['highlight'] ||= '#FFFFFF'
    self.styles['client']['colors']['warning']   ||= '#FF0000'
    self.styles['client']['content'] ||= {}
  end

  def sanitize_branding_url
    self.url = self.url.sub(/^https?\:\/\/(www.)?/,'')
  end

  def check_default
    if profileable.branding_profiles.count > 1 &&
       default?

      profileable.branding_profiles
        .where(default: true)
        .where
        .not(id: id)
        .update default: false
    end
  end

  def check_global_default
    BrandingProfile.where(global_default: true).where.not(id: id).update(global_default: false) if global_default?
  end

  def set_up_from_master
    #@gc = Agency.where(master_agency: true).order("id asc").limit(1).take
    #@gc_branding = @gc.branding_profiles.first
    #@gc_branding.pages.each do |pg|
    #  new_pg = pg.dup
    #  new_pg.branding_profile = self
    #  new_pg.save
    #end
    #@gc_branding.branding_profile_attributes.each do |bpa|
    #  new_bpa = bpa.dup
    #  new_bpa.branding_profile = self
    #  new_bpa.save
    #end
  end
end
