class KlaviyoService

  include HTTParty

  attr_accessor :lead

  EVENTS = ["New Lead", "Became Lead", "New Lead Event", "Created Account", "Updated Account",
            "Updated Email", "Reset Password", "Invoice Created", "Order Confirmation", "Failed Payment"]
  TEST_TAG = 'test'

  #need to disable sending in test env
  def initialize
    @klaviyo ||= Klaviyo::Client.new(Rails.application.credentials.klaviyo[ENV["RAILS_ENV"].to_sym][:token] || ENV["KLAVIYO_API_TOKEN"])
    @private_api_key ||= Rails.application.credentials.klaviyo[ENV["RAILS_ENV"].to_sym][:private_token]
  end

  def process_events(event_description, event_details={}, &block)
    raise 'Method should be used with block.' unless block_given?
    raise 'Unknown event. Please check EVENTS list in helper.' unless EVENTS.include?(event_description)

    self.lead = event_details  if event_details.is_a?(Lead)
    begin
      response = yield

      track_event(event_description, event_details) unless ["test", "test_container", "local", "development"].include?(ENV["RAILS_ENV"])

    rescue Net::OpenTimeout => ex
      Rails.logger.error "LeadEventsController KlaviyoException: #{ex.to_s}."
    ensure
      #need to check what to return in controller
      response = true
    end

  end

  private

  def identify_lead(event_description, event_details = {})
    @klaviyo.identify(email: @lead.email, id: @lead.identifier, properties: identify_properties, customer_properties: identify_customer_properties(identify_properties))
  end

  #need to send to lead to prod only in prod
  def track_event(event_description, event_details = {})
    customer_properties = {}
    if event_description == "New Lead"
      identify_lead("New Lead")
      customer_properties[:email] = @lead.email
    end

    if event_description == "Became Lead"
      identify_lead("Became Lead")
    end

    if event_description == "New Lead Event"
      if @lead.lead_events.count > 1
        event_details = @lead.lead_events.last.as_json
        identify_lead("Became Lead") if @lead.lead_events.last.agency_id.present? && @lead.agency_id != @lead.lead_events.last.agency_id
      end
    end

    if event_description == 'Updated Email'
      identify_lead('Became Lead (email)')
      response = HTTParty.get("https://a.klaviyo.com/api/v2/people/search?api_key=#{@private_api_key}&email=#{event_details[:email]}")
      lead_id = JSON.parse(response.body)["id"]
      if lead_id.present?
        HTTParty.put("https://a.klaviyo.com/api/v1/person/#{lead_id}?api_key=#{@private_api_key}&email=#{event_details[:new_email]}")
      end
    end

    customer_properties[:last_visited_page_url] = map_last_visited_url(event_details) #need to unify for other too
    customer_properties[:last_visited_page] = event_details["data"].present? ? event_details["data"]["last_visited_page"] : "Landing Page"

    #need to add rescue according to prod 500 error
    @klaviyo.track(event_description,
                   email: @lead.email,
                   properties: prepare_track_properties(event_details),
                   customer_properties: customer_properties
    )
  end

  #tbd maybe need to separate in module and map from model, like address, profile etc.
  def prepare_track_properties(event_details)
    request = { status: @lead.status,
                uuid: @lead.identifier
                #last_visited_page: event_details["data"]["last_visited_page"]
    }
    if event_details.present?
      request['$event_id'] = event_details["id"]
      if event_details["data"].present?
        request.merge!(event_details["data"])
      end
      if event_details[:profile_attributes].present?
        identify_customer_properties(request)
      end
      if event_details[:address_attributes].present?
        identify_customer_properties(request)
      end

    end

    request
  end

  def identify_customer_properties(request)
    if @lead.profile.present?
      request.merge!(@lead.profile.as_json.except("id", "profileable_type", "profileable_id","created_at","updated_at"))
    end
    if @lead.address.present?
      request.merge!(@lead.address.as_json.except("id","plus_four","full_searchable","primary","addressable_type","addressable_id","created_at","updated_at","searchable"))
    end
    request
  end

  def identify_properties
    request = {
        '$id': @lead.identifier,
        '$email': @lead.email,
        '$first_name': @lead.profile.try(:first_name),
        '$last_name': @lead.profile.try(:last_name),
        '$phone_number': @lead.profile.try(:contact_phone),
        '$title': @lead.profile.try(:job_title),
        '$organization': @lead.profile.try(:title),
        '$city': @lead.address.try(:city),
        '$region': @lead.address.try(:state),
        '$country': @lead.address.try(:country),
        '$zip': @lead.address.try(:zip_code),
        '$image': "",
        '$consent': "",
        'status': @lead.status,
        'tag': @lead.lead_events.last.try(:tag),
        'environment': ENV["RAILS_ENV"],
        'agency': @lead.try(:agency).try(:title)
    }
    request
  end

  def set_tag
    if @lead.email.include?('test')
      TEST_TAG
    else
      @lead.lead_events.last.try(:tag)
    end
  end

  def map_last_visited_url(event_details)
    return "https://www.getcoveredinsurance.com/rentguarantee" if event_details.blank?
    if event_details['policy_type_id']==5
      "https://www.getcoveredinsurance.com/rentguarantee"
    else
      #tbd for other forms
      "https://www.getcoveredinsurance.com/rentguarantee"
    end
  end

end
