#!/usr/bin/env ruby

# Generate seed for Leads dashboard

require 'faker'

# User.delete_all
BrandingProfile.delete_all
TrackingUrl.delete_all
Lead.delete_all
LeadEvent.delete_all

agencies = Agency.all

email = "fakeuser@getcoveredllc.com"
password = Faker::String.random

user = User.find_by(email: email)
user.delete if user

user = ::User.create(
  email: email,
  password: password,
  password_confirmation: password,
  profile_attributes: {
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name ,
    birth_date: Faker::Time.backward(days: 365*25 , period: :evening),
    contact_phone: Faker::PhoneNumber.cell_phone_in_e164
  }
)

Profile.create!(
  first_name: Faker::Name.first_name,
  last_name: Faker::Name.last_name ,
  profileable_id: user.id
)

agency = agencies.first

branding_profile = BrandingProfile.create(
  url: Faker::Internet.url,
  profileable_type: "Agency",
  profileable_id: agency.id,
  logo_url: Faker::Avatar.image,
  footer_logo_url: Faker::Avatar.image,
  logo_jpeg_url: Faker::Internet.url,
)
branding_profile.save!


100.times do

  agencies.each do |agency|
    TrackingUrl.create!(
      landing_page: Faker::Internet.url,
      campaign_name: Faker::Internet.slug,
      campaign_source: Faker::Internet.slug,
      campaign_medium: "facebook",
      campaign_term: Faker::Internet.slug,
      campaign_content: Faker::Alphanumeric.alphanumeric(number: 12),
      agency_id: agency.id,
      branding_profile_id: branding_profile.id
    )
  end

end

tracking_urls = TrackingUrl.all
lead_status = %i[prospect return converted lost archived]

10000.times do

  tracking_url = tracking_urls[rand(1...100)]

  pages_cx = Lead::PAGES_RENT_GUARANTEE.length
  last_visited_page = Lead::PAGES_RENT_GUARANTEE[rand(0...pages_cx+1)]
  Lead.create!(
    email: Faker::Internet.unique.email,
    identifier: Faker::Name.unique.name,
    last_visit:  DateTime.now - (rand(1...730)).day,
    last_visited_page: last_visited_page,
    agency_id: agency.id,
    branding_profile_id: branding_profile.id,
    tracking_url_id: tracking_url.id,
    status: lead_status.sample
  )
end

leads = Lead.all
policy_types = PolicyType.all

1000.times do
  lead = leads[rand(1...999)]
  LeadEvent.create!(
    data: {},
    tag: Faker::Name.unique.name,
    latitude: Faker::Address.latitude,
    longitude: Faker::Address.longitude,
    lead_id: lead.id,
    policy_type_id: policy_types[rand(0...2)].id,
    agency_id: agency.id,
    branding_profile_id: branding_profile .id
  )
end


