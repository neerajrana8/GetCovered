module V2
  module StaffReporting
    class PolicyEntriesController < StaffReportingController
      
      before_action :set_account, only: %i[index fake_report]
      
      SUPPORTED_FILTERS = (
        [
          :account_title, :number, :yardi_property, :community_title,
          :yardi_unit, :unit_title, :street_address, :city, :state,
          :zip, :carrier_title, :yardi_lease,
          :primary_policyholder_first_name, :primary_policyholder_last_name,
          :primary_policyholder_email, :primary_lessee_first_name,
          :primary_lessee_last_name, :primary_lessee_email, :any_lessee_email
        ].map{|x| [x, [:scalar, :array, :like]] } + [
          :id, :account_id, :policy_id, :lease_id, :community_id, :unit_id
        ].map{|x| [x, [:scalar, :array]] } + [
          :expiration_date, :effective_date
        ].map{|x| [x, [:scalar, :array, :interval]] } + [
          :expires_before_lease, :applies_to_lessee
        ].map{|x| [x, [:scalar, :array]] } + [
          [:lease_status, [:scalar, :array]]
        ]
      ).to_h
    
      def index
        @export = true if params[:export]
        super(:@policy_entries, hacky_thing(@account.nil? ? ::Reporting::PolicyEntry.all : ::Reporting::PolicyEntry.where(account_id: @account.id)))
      end
      
      def hacky_thing(base_request)
        case params[:special]
          when "expiring"
            base_request.where(expiration_date: (Time.current.to_date)...(Time.current.to_date + 30.days))
          when "expired"
            base_request.where(expiration_date: (Time.current.to_date - 30.days)...(Time.current.to_date))
          else
            base_request
        end
      end
      
      def fake_report
        show_account = @organizable.nil?
        yardi_mode = @organizable && @organizable.integrations.where(provider: "yardi").count > 0
        manifest = {
          title: "Policies",
          root_subreport: "Policies",
          subreports: [
            { path: "", title: "Policies" },
            { path: "/recent/expiring", title: "Expiring within 30 Days" },
            { path: "/recent/expired", title: "Expired within 30 Days" }
          ].map do |version|
            {
              title: version[:title],
              endpoint: "/v2/reporting/policy-entries#{version[:path]}",
              fixed_filters: {},
              unique: ["id"],
              columns: [
                { title: "id", apiIndex: "id", invisible: true },
                { title: "account_id", apiIndex: "account_id", invisible: true },
                { title: "policy_id", apiIndex: "policy_id", invisible: true },
                { title: "lease_id", apiIndex: "lease_id", invisible: true },
                !show_account ? nil : { title: "Account", apiIndex: "account_title", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Carrier", apiIndex: "carrier_title", sortable: true, filters: ["scalar", "array", "like"] },
                !yardi_mode ? nil : { title: "Yardi Lease", apiIndex: "yardi_lease", sortable: true, filters: ["scalar", "array", "like"] },
                !yardi_mode ? nil : { title: "Lease Status", apiIndex: "lease_status", sortable: true,
                  data_type: "enum",
                  enum_values: ::Lease.statuses.keys,
                  format: ::Lease.statuses.keys.map{|k| k.titlecase }
                },
                { title: "Community", apiIndex: "community_title", sortable: true, filters: ["scalar", "array", "like"] },
                !yardi_mode ? nil : { title: "Yardi Property", apiIndex: "yardi_property", sortable: true, filters: ["scalar", "array", "like"] },
                !yardi_mode ? nil : { title: "Unit", apiIndex: "yardi_unit", sortable: true, filters: ["scalar", "array", "like"] },
                yardi_mode ? nil : { title: "Unit", apiIndex: "unit_title", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Street Address", apiIndex: "street_address", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "City", apiIndex: "city", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "State", apiIndex: "state", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Zip", apiIndex: "zip", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Policy", apiIndex: "number", sortable: true, filters: ["scalar", "array", "like"] },
                !@organizable.nil? ? nil : { title: "Applies to Lessee", apiIndex: "applies_to_lessee", sortable: true, filters: ["scalar"], data_type: "boolean", format: "YN" },
                { title: "Effective", apiIndex: "effective_date", sortable: true, filters: ["scalar", "array", "interval"], data_type: "date" },
                { title: "Expiration", apiIndex: "expiration_date", sortable: true, filters: ["scalar", "array", "interval"], data_type: "date" },
                { title: "Expires Before Lease", apiIndex: "expires_before_lease", sortable: true, filters: ["scalar"], data_type: "boolean", format: "YN" },
                { title: "First Name", apiIndex: "primary_policyholder_first_name", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Last Name", apiIndex: "primary_policyholder_last_name", sortable: true, filters: ["scalar", "array", "like"] },
                { title: "Email", apiIndex: "any_email", sortable: true, filters: ["scalar", "array", "like"] },
              ].compact
            }
          end,
          subreport_links: []
        }
        render json: { id: 1, manifest: manifest },
          status: 200
      end
      
      
        def set_account
          @account = if @organizable
            if @organizable.class == ::Account
              @organizable
            else
              :THROW_A_500_ONLY_ACCOUNTS_CAN_DO_THIS
            end
          else
            nil
          end
        end

=begin
        def fixed_filters
        # doesn't work for some reason
          case params[:special]
            when "expiring"
              {
                expiration_date: { 'start' => (Time.current.to_date).to_s, 'before' => (Time.current.to_date + 30.days).to_s },
                applies_to_lessee: @organizable.nil? ? [true, false] : [true]
              }
            when "expired"
              {
                expiration_date: { 'start' => (Time.current.to_date - 30.days).to_s, 'before' => (Time.current.to_date).to_s },
                applies_to_lessee: @organizable.nil? ? [true, false] : [true]
              }
            else
              {
                applies_to_lessee: @organizable.nil? ? [true, false] : [true]
              }
          end
        end
=end
        def default_filters
          {}
        end
        
        def supported_filters
          SUPPORTED_FILTERS
        end
      
        def default_pagination_per
          50
        end
        
        def view_path
          'v2/shared/reporting/policy_entries'
        end
        
        def v2_should_render
          { short: true, index: true }
        end
        
        def v2_default_to_short
          true
        end

    end # end controller
  end
end
