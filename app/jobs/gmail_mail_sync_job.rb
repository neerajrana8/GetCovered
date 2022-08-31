class GmailMailSyncJob < ApplicationJob
  queue_as :default
  require 'google/apis/gmail_v1'
  require 'googleauth'
  require 'googleauth/stores/file_token_store'
  require 'fileutils'

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
  APPLICATION_NAME = 'Gmail Sync'.freeze
  CREDENTIALS_PATH = "#{Rails.root}/config/credentials.json".freeze
  # The file token.yaml stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  TOKEN_PATH = "#{Rails.root}/config/token.yaml".freeze
  SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY
  def perform(type)
    if type === 0
      full_sync
    elsif type === 1
      partial_sync
    end
  end

  private

  def partial_sync
    service = Google::Apis::GmailV1::GmailService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize
    user_id = 'me'
    history_id = ContactRecord.where(source: "gmail").last.thread_id
    result = service.list_user_histories(user_id, start_history_id: history_id)
    if result.history.count > 0
      result.history.each do |f|
        mail_data = service.get_user_message(user_id, f.messages.last.id)
        process_message(mail_data)
      end
    else
      logger.info "No new mails"
    end
  end


  def full_sync
    service = Google::Apis::GmailV1::GmailService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize
    user_id = 'me'
    result = service.list_user_messages(user_id, max_results: 500)
    result.messages.reverse_each do |f|
      mail_data = service.get_user_message(user_id, f.id)
      process_message(mail_data)
    end
  end

  def process_message(mail_data)
    from_email_id = find_email(mail_data.payload.headers.detect { |f| f.name === 'From' }.value).downcase
    to_email_id = find_email(mail_data.payload.headers.detect { |f| f.name === 'To' }.value).downcase
    user = User.where(email: [from_email_id, to_email_id])
    if  user.count > 0
      record_mail(mail_data, user.last)
    else
      logger.info to_email_id + "user not found"
    end
  end

  def record_mail(mail_data, user)

    contact_record = ContactRecord.new(
      approach: 'email',
      direction: 'incoming',
      status: 'Delivered',
      contactable: user,
      body: mail_data.payload.body.data ? mail_data.payload.body.data : mail_data.snippet ,
      source: 'gmail',
      thread_id: mail_data.history_id,
      subject: mail_data.payload.headers.detect { |f| f.name === 'Subject' }.value
    )
    contact_record.save
  end

  def find_email(string)
    string[/<([^>]*)>$/, 1] || string
  end
  def authorize
    client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = 'default'
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
      code = '4/1AdQt8qjoB7o1sJ_XmQGO2iixmbrOTJc_sY51SE6PS_h49g6TEv6z8TkI64E'
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end
end
