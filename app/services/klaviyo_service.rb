class KlaviyoService

  include HTTParty

  attr_accessor :lead

  EVENTS = ["New Lead", "Became Lead", "New Lead Event", "Created Account", "Updated Account",
            "Updated Email", "Reset Password", "Invoice Created", "Order Confirmation", "Failed Payment"]

  TEST_TAG = 'test'
  RETRY_LIMIT = 3

  def initialize
    Klaviyo.public_api_key = Rails.application.credentials.klaviyo[ENV["RAILS_ENV"].to_sym][:token] || ENV["KLAVIYO_API_TOKEN"]
    Klaviyo.private_api_key = Rails.application.credentials.klaviyo[ENV["RAILS_ENV"].to_sym][:private_token]
    @retries = 0
  end

  def process_events(event_description, event_details={}, &block)
    raise 'Method should be used with block.' unless block_given?
    raise 'Unknown event. Please check EVENTS list in helper.' unless EVENTS.include?(event_description)

    self.lead = event_details  if event_details.is_a?(Lead)
    begin
      response = yield

      if event_description == "Became Lead" && event_details.blank?

      else
        track_event(event_description, event_details) #unless ["test", "test_container", "local", "development"].include?(ENV["RAILS_ENV"])
      end

    rescue Net::OpenTimeout => ex
      Rails.logger.error("LeadEventsController KlaviyoException: #{ex.to_s}.")
    ensure
      #need to check what to return in controller
      response = true
    end

  end

  private

  def identify_lead(event_description, event_details = {})
    Klaviyo::Public.identify(email: @lead.email, id: @lead.identifier, properties: identify_properties,
                      customer_properties: identify_customer_properties(identify_properties))
  end

  #TODO: need to send to lead to prod only in prod
  def track_event(event_description, event_details = {})
    customer_properties = {}
    identify_lead(event_description)

    customer_properties[:email] = @lead.email if event_description == "New Lead"

    event_details = @lead.lead_events.last.as_json if event_description == "New Lead Event" && @lead.lead_events.count > 0

    if event_description == 'Updated Email'
      response = HTTParty.get("https://a.klaviyo.com/api/v2/people/search?api_key=#{Klaviyo.private_api_key}&email=#{event_details[:email]}")
      lead_id = JSON.parse(response.body)["id"]
      if lead_id.present?
        HTTParty.put("https://a.klaviyo.com/api/v1/person/#{lead_id}?api_key=#{Klaviyo.private_api_key}&email=#{event_details[:new_email]}")
      end
    end

    customer_properties[:last_visited_page_url] = map_last_visited_url(event_details)
    customer_properties[:last_visited_page]     = map_last_visited_page(event_details) if page_set?(event_details)
    customer_properties[:branding_profile_url]  = map_branding_profile_url(event_details)
    customer_properties[:pm_account_title]  = map_pm_account(event_details)

    # TODO: check retriable gem?
    begin
      result = Klaviyo::Public.track(event_description,
                   email: @lead.email,
                   properties: prepare_track_properties(event_details),
                   customer_properties: customer_properties
      )
      Rails.logger.info("LeadEventsController KlaviyoTrack: desc: #{event_description},result: #{result.to_s}, lead: #{@lead.as_json}, event_details: #{event_details}, properties: #{prepare_track_properties(event_details)}, customer_properties: #{customer_properties}, last_event: #{@lead.lead_events.last.as_json}.")
    rescue => kl_ex
      Rails.logger.error("LeadEventsController KlaviyoException: #{kl_ex.to_s}, lead: #{@lead.as_json}, event_details: #{event_details}, properties: #{prepare_track_properties(event_details)}, customer_properties: #{customer_properties}.")
      @retries += 1
      @retries > RETRY_LIMIT ? Rails.logger.error("LeadEventsController KlaviyoException after retries: #{kl_ex.to_s}, lead: #{@lead.as_json}, event_details: #{event_details}.") : retry
    end
  end

  #tbd maybe need to separate in module and map from model, like address, profile etc.
  def prepare_track_properties(event_details)
    request = { status: @lead.status,
                uuid: @lead.identifier
              }
    if event_details.present?
      request['$event_id'] = event_details["id"]

      request.merge!(event_details["data"]) if event_details["data"].present?
      if event_details[:profile_attributes].present? || event_details[:address_attributes].present?
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
        '$image': "",
        '$consent': "",
        'status': @lead.status,
        'tag': @lead.lead_events.last.try(:tag),
        'environment': ENV["RAILS_ENV"],
        'last_visited_page': @lead.last_visited_page,
        'policy_type': @lead.last_event&.policy_type&.slug
    }
    setup_locale!(request)
    setup_profile!(request)
    setup_address!(request)
    setup_agency!(request)
    request
  end

  def setup_locale!(request)
    if @lead.last_event&.data.present?
      request.merge!({'locale': @lead.last_event&.data['locale']})
    end
  end

  def setup_address!(request)
    if @lead.address.present?
      request.merge!({'$city': @lead.address.try(:city),
       '$region': @lead.address.try(:state),
       '$country': @lead.address.try(:country),
       '$zip': @lead.address.try(:zip_code)})
    end
  end

  def setup_profile!(request)
    if @lead.profile.present?
      request.merge!({'$first_name': @lead.profile.try(:first_name),
       '$last_name': @lead.profile.try(:last_name),
       '$phone_number': @lead.profile.try(:contact_phone),
       '$title': @lead.profile.try(:job_title),
       '$organization': @lead.profile.try(:title)})
    end

  end

  def setup_agency!(request)
    lead_agency = @lead.try(:agency)
    if lead_agency.present?
      if lead_agency.sub_agency?
        request.merge!({'agency': lead_agency.agency.try(:title),
                        'sub_agency': lead_agency.try(:title) })
      else
        request.merge!({'agency': lead_agency.try(:title),
                        'sub_agency': 'No Sub Agency'})
      end
    end
  end

  def set_tag
    if @lead.email.include?('test')
      TEST_TAG
    else
      @lead.lead_events&.last&.try(:tag)
    end
  end

  def page_set?(event_details)
    event_details['last_visited_page'] || (event_details["data"] && event_details["data"]["last_visited_page"])
  end

  def map_branding_profile_url(event_details)
    if event_details["data"].present?
      branding_id = event_details["data"]["branding_profile_id"]
      BrandingProfile.find(branding_id)&.url if branding_id
    else
      ""
    end
  end

  def map_pm_account(event_details)
    result = Account.find(@lead.account_id)&.title if @lead.account_id.present?
    if result.blank? && event_details["data"].present? && event_details["data"]["insurable_id"]&.present?
      result = Insurable.find(event_details["data"]["insurable_id"])&.account&.title
    end
    result
  end

  def map_last_visited_page(event_details)
    default = @lead.last_event.policy_type.rent_guarantee? ? Lead::PAGES_RENT_GUARANTEE[0] : Lead::PAGES_RESIDENTIAL[0]
    if event_details["data"].present? && @lead.page_further?(event_details["data"]["last_visited_page"])
      event_details["data"]["last_visited_page"]
    else
      @lead.last_visited_page || default
    end
  end

  def map_last_visited_url(event_details)
    return "" if event_details.blank?
    #need to update after multiple brandings setup
    branding_url = @lead.agency.branding_profiles.take.url
    if @lead.last_event&.policy_type&.rent_guarantee?
      "https://#{branding_url}/rentguarantee"
    elsif @lead.last_event&.policy_type&.residential?
      "https://#{branding_url}/residential"
    else
      #tbd for other forms
      ""
    end
  end

  def is_agency_updated?
    @lead.lead_events.last.agency_id.present? && @lead.agency_id != @lead.lead_events.last.agency_id
  end

end
