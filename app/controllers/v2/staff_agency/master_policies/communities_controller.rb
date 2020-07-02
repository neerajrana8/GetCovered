module V2
  module StaffAgency
    module MasterPolicies
      class CommunitiesController < StaffAgencyController
        before_action :set_master_policy
        before_action :find_community, only: %i[show create add destroy]

        def index

        end

        def show

        end

        def create

        end

        def add

        end

        def show

        end

        private

        def set_master_policy
          @master_policy = Policy.find_by(policy_type_id: PolicyType::MASTER_ID, id: params[:id])
        end

        def find_community
          @community = @master_policy.insurables.communities.find(params[:id])
        end

        def create_community_params

        end
      end
    end
  end
end
