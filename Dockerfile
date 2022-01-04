FROM ubuntu:20.04
FROM ruby:3.0.1
MAINTAINER dylan@getcoveredllc.com

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y build-essential locales locales-all nodejs imagemagick

# Use en_US.UTF8 as our locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV BUNDLE_VERSION 2.2.27

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

RUN gem install bundler --version $BUNDLE_VERSION
RUN bundle config --global frozen 1
RUN bundle config set --local path '/bundle'
RUN RAILS_ENV=production bundle install
COPY . /getcovered

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]