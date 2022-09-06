##
# V2 StaffSuperAdmin Accounts Controller
# File: app/controllers/v2/staff_super_admin/accounts_controller.rb

module V2
  module StaffSuperAdmin
    module SpecialTasks
      class LeaseCoverageReportsController < StaffSuperAdminController

        GOOSE_RESPONSES = [
          "The goose waddles fearlessly up to you, a small basket held by the handle in its mouth. You look down, surprised--what's this? It seems to be the data you requested.",
          "The goose has delivered. Honk honk.",
          "Such majesty is exuded by the large goose upon the lake in front of you. Wait--that isn't just majesty! What you had taken for pure majesty is in fact an admixture of majesty and data.",
          "Behold the joyful gift of the goose!",
          "Softly gliding o'er the waves/providing data unto knaves<br></br>and lords of men if they should ask<br></br>--thus I describe my goosely task.",
          "As the goose walks away, for a moment you think you see the silhouette of Miguel walking beside it--then the image is gone.",
          "A gracious goose hath come to thee, a-honkin' and a-stompin'.",
          "Such fluffy down, such orange beak! Through CSVs this goose can speak!",
          "Fear not the feathered fellow, for he merely brings you spreadsheets.",
          "HONK HONK!!!",
          "Fun fact: Geese have freakin' teeth! (Really. I advise you not look it up. You'll have nightmares.)",
          "What thou hast sought this goose hath brought.",
          <<~ENDSTR.gsub("\n\n", "</p><p>").gsub("\n", "<br></br>"),
            <p>"A 'V' upon the vast expanse of sky
            and strangeling yelps that echo in the air
            --what apparition this? O tell me why
            these migratory birds are come, and where

            their true desires dwell, O sagely man!"
            He stroked his beard a while, and answered thus:
            "These geese are here for thee. Whene'er they can,
            with he who heads the flock they bring to us

            what grim reports we ask; that one alone,
            their leader, bears this duty on his wings;
            but for companionship these too have flown,
            to bring us CSVs and other things.

            The birds have come but at thine own request;
            take then thy file, and count thyself most blessed."</p>
          ENDSTR
          "GOOSE DELIVERY!!!",
          "The goose is here! The goose is here! No, no, children, get back to bed; the goose is only here to bring me reports.",
          "HOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOONK!!!",
          "My goodness, it's a whole gaggle of geese! The entire flock accompanied our friend this time!",
          "Goose be nimble, goose be quick; goose be nice and do a trick! He bring report, he bring for you; pat goose three times, then work must do.",
          "Trit-trot. Flip-flap. Goose time.",
          "Sure, geese are cool and all, but what do the DO for us? Nothing! ...wait, what's that? Is that a goose... with a basket? IS IT BRINGING YOU WORK DOCUMENTS OMG WHAT?!?!?!",
          "Behold! From a distant pond he approaches! A basket clutched in his bill! THIS GOOSE! THIS. GOOSE. RIGHT. HERE!",
          "Honk honk. Honk honk csv honk. Honspreadheetsk sprehonkadsheets honkspreahonkdsheethonk cshonkv. Honk.",
          "HONK.",
          "HONK HONK.",
          "HONK. HONK. HOOOOOOOONK!!!",
          "D-liver-E from a G-oo-S-E N-O-W H-E-re.",
          "The goose sends his compliments.",
          "What do you get when you cross a goose with another goose? YET ANOTHER GOOSE!",
          "What's the difference between a goose and a duck? Okay, I'll tell you: one is a goose, and one is a duck.",
          "What's the difference between a goose and a swan? Grace of from? Yeah I guess, that's true, sure. But there's a more important difference: work ethic.",
          "BIG HONKIN GOOSE WITH A BIG HONKIN SPREADSHEET!",
          "His wide and orange feet leave tiny puddles in the mud where'er he walks.",
          "Hearing a strange noise in the sky, you raise your head. Oh my! It's that big honkin' goose! He must have another report for you.",
          "READ MY BILL: H-O-N-K!"
        ]

        def defaults_for
          defaults = {
            start_date_start: nil,
            start_date_end: nil,
            end_date_start: nil,
            end_date_end:  nil,
            lease_statuses: ['current'],
            show_only: nil, # 'uncovered', 'covered', 'internal', 'external'
            show_moveouts: true,
            permissive: true,
            include_mp_data: true
          }
          defaults.merge!(case params[:account_id].to_i
            when 45
              {
                start_date_start: "2022-04-29"
              }
            else
              {}
          end)
          # render defaults
          render json: defaults, status: 200
        end

        def generate
          recipient = params[:email].to_s
          # grab parameters
          account = Account.find(params[:account_id].to_i)
          start_date_start = (Date.parse(params[:start_date_start]) rescue nil)
          start_date_end = (Date.parse(params[:start_date_end]) rescue nil)
          end_date_start = (Date.parse(params[:end_date_start]) rescue nil)
          end_date_end = (Date.parse(params[:end_date_end]) rescue nil)
          lease_statuses = params[:lease_statuses]
          show_only = params[:show_only]
          show_moveouts = params[:show_moveouts]
          permissive = params[:permissive]
          include_mp_data = params[:include_mp_data]
          hide_defunct = true; # we always hide defunct leases, but it's an option in the script. should be outdated since they should be marked expired now
          # make extra parameters
          per_user_coverage = !permissive
          start_date_range = if start_date_start.nil? && start_date_end.nil?
              nil
            elsif start_date_start.nil?
              (Date.parse("1776-07-04")...start_date_end)
            elsif start_date_end.nil?
              (start_date_start...)
            else
              (start_date_start...start_date_end)
          end
          end_date_range = if end_date_start.nil? && end_date_end.nil?
              nil
            elsif end_date_start.nil?
              (Date.parse("1776-07-04")...end_date_end)
            elsif end_date_end.nil?
              (end_date_start...)
            else
              (end_date_start...end_date_end)
          end
          # generate csv
          csv = CSV.generate(headers: true) do |csv|
            ActiveRecord::Base.logger.level = 1
            csv << (
              [
                "User Email", "User Name", "Lessee?", "Primary Lessee?", "Move In", "Move Out", "Lease Start", "Lease End",
                "Community Name", "Building Address", "Unit Number",
                "Resident Code", "Primary Lessee Tcode",
                "Most Recent HO4 Policy", "HO4 Status", "HO4 Effective", "HO4 Expiration", "HO4 Carrier"
              ] + (include_mp_data ? [
                "Most Recent Master Policy Coverage", "MPC Status", "MPC Effective", "MPC Expiration",
              ] : []) + [
                "HO4 Policy ID", "MPC Policy ID", "Lease ID", "Unit ID", "Community ID", "User ID"
              ]
            )              
            leases = account.leases; nil
            leases = leases.where(start_date: start_date_range) unless start_date_range.nil?; nil
            leases = leases.where(end_date: end_date_range) unless end_date_range.nil?; nil
            leases = leases.where(status: lease_statuses) unless lease_statuses.nil?; nil
            leases = leases.where(defunct: false) unless !hide_defunct; nil
            leases.each do |lease|
              policies = if per_user_coverage
                Policy.references(:policy_insurables).includes(:policy_insurables).where(
                  id: PolicyUser.where(user_id: lease.lease_users.pluck(:user_id)).where.not(policy_id: nil).pluck(:policy_id),
                  policy_type_id: [1, 3]
                ).where.not(status: ['EXTERNAL_UNVERIFIED', 'EXTERNAL_REJECTED', 'BIND_REJECTED']).select{|p| p.policy_insurables.find{|x| x.primary }&.insurable_id == lease.insurable_id }.group_by{|p| p.policy_type_id }
              else
                Policy.references(:policy_insurables).includes(:policy_insurables).where(
                  policy_insurables: { primary: true, insurable_id: lease.insurable_id },
                  policy_type_id: [1, 3]
                ).where.not(status: ['EXTERNAL_UNVERIFIED', 'EXTERNAL_REJECTED', 'BIND_REJECTED']).uniq.group_by{|p| p.policy_type_id }
              end
              case show_only.to_sym
                when :uncovered
                  next if (policies[1] || []).any?{|p| Policy.active_statuses.include?(p.status) }
                when :covered
                  next if !(policies[1] || []).any?{|p| Policy.active_statuses.include?(p.status) }
                when :internal
                  next if !(policies[1] || []).any?{|p| Policy.active_statuses.select{|s| !s.start_with?("EXTERNAL") }.include?(p.status) }
                when :external
                  next if !(policies[1] || []).any?{|p| Policy.active_statuses.select{|s| s.start_with?("EXTERNAL") }.include?(p.status) }
                else
                  nil # do nothing
              end
              lease.lease_users.each do |lu|
                next if !show_moveouts && lu.moved_out_at && lu.moved_out_at < Time.current.to_date
                ho4 = policies[1]&.select{|p| per_user_coverage ? p.policy_users.any?{|pu| pu.user_id == lu.user_id  } : true }&.max_by{|p| [Policy.active_statuses.include?(p.status) ? 1 : 0, p.effective_date] }
                mpc = policies[3]&.select{|p| per_user_coverage ? p.policy_users.any?{|pu| pu.user_id == lu.user_id } : true }&.max_by{|p| [Policy.active_statuses.include?(p.status) ? 1 : 0, p.effective_date] }
                csv << ([
                  lu.user&.email || lu.user&.profile&.contact_email,
                  lu.user&.profile&.full_name,
                  lu.lessee ? "Yes" : "No",
                  lu.primary ? "Yes" : "No",
                  lu.moved_in_at&.to_s || "",
                  lu.moved_out_at&.to_s || "",
                  lease.start_date&.to_s || "",
                  lease.end_date&.to_s || "",
                  lease.insurable.parent_community.title,
                  lease.insurable.primary_address.full,
                  lease.insurable.title,
                  lu.integration_profiles.take&.external_id,
                  lease.integration_profiles.take&.external_id,
                  ho4&.number,
                  ho4&.status,
                  ho4&.effective_date,
                  ho4&.expiration_date,
                  ho4&.carrier&.title || ho4&.out_of_system_carrier_title
                ] + (include_mp_data ? [
                  mpc&.number,
                  mpc&.status,
                  mpc&.effective_date,
                  mpc&.expiration_date,
                ] : []) + [
                  ho4&.id,
                  mpc&.id,
                  lease.id,
                  lease.insurable_id,
                  lease.insurable.parent_community.id,
                  lu.user_id
                ])
              end
            end
          end # end csv

          dat_email = ActionMailer::Base.mail(
            from: "big.honkin.goose@getcoveredllc.com", 
            to: email, 
            subject: "#{account&.title} Report: #{per_user_coverage ? "Strict" : "Permissive"}#{hide_defunct ? "" : " + Defunct"}",
            body: GOOSE_RESPONSES[rand(GOOSE_RESPONSES.length)]
          )
          dat_email.attachments["lcr_#{account&.title}_#{Time.current.to_date.to_s}_#{per_user_coverage ? "strict" : "permissive"}.csv"] = {
            mime_type: 'text/csv',
            content: csv
          }
          dat_email.deliver_now
          
          render json: { success: true }, status: 200
        end # def generate
        
        

      end # class
    end # module SpecialTasks
  end # module StaffSuperAdmin
end
