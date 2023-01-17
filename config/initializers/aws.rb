#require 'aws-sdk-s3'
require 'aws-sdk-core'

env = Rails.env.to_sym
if Rails.application.credentials.aws
  aws_access_key_id = Rails.application.credentials.aws[env][:access_key_id]
  aws_secret_access_key = Rails.application.credentials.aws[env][:secret_access_key]
  aws_region = Rails.application.credentials.aws[env][:region]
  aws_bucket_name = Rails.application.credentials.aws[env][:bucket]
  Aws.config.update({
                      region: aws_region,
                      credentials: Aws::Credentials.new(aws_access_key_id, aws_secret_access_key),
                    })

  $S3_BUCKET = Aws::S3::Resource.new.bucket(aws_bucket_name)
end