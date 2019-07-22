module V2
  module Staff
    class SearchController < StaffController
      before_action :draw
      
      def hunt
        render json: @query.results.to_json,
               status: 200  
      end
          
      private
      
        def draw
          unless params[:query].nil?
            @query = Elasticsearch::Model.search(params[:query], 
                                                 [Address, Building, Claim, 
                                                  Community, Lease, MasterPolicyCoverage, 
                                                  MasterPolicy, Policy, Profile, Unit])
          else
            render json: { error: "Search Missing" }, 
                   status: 422
          end
        end
    end
  end
end
