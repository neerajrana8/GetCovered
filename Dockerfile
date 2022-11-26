FROM ubuntu:14.04
FROM ruby:3.0.1
MAINTAINER dylan@getcoveredllc.com

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y \
  build-essential \
  locales \
  nodejs \
  imagemagick

# Use en_US.UTF8 as our locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV RACK_TIMEOUT_SERVICE_TIMEOUT 25

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /getcovered
WORKDIR /getcovered

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.2.27 && RAILS_ENV=development bundle install --jobs 20 --retry 5

# Copy the main application.
COPY Gemfile /getcovered/
COPY Gemfile.lock /getcovered/

RUN RAILS_ENV=development bundle install --path /bundle
COPY . /getcovered

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000
