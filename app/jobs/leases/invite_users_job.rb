module Leases
  class InviteUsersJob < ApplicationJob
    queue_as :default
    before_perform :set_invoices

    def perform(lease)
      client_host = ::BrandingProfiles::FindByObject.run!(object: lease.insurable)&.url
      lease.users.each { |user| user.invite!(nil, client_host: client_host) unless user.invitation_accepted_at.present? }
    end
  end
end
