DocRaptor.configure do |config|
  config.username = Rails.application.credentials.docraptor_api_key
  config.debugging = ["local", "development", "test", 
                      "awsdev", "aws_staging"].include?(ENV["RAILS_ENV"]) ? true : false
end

$docraptor = DocRaptor::DocApi.new