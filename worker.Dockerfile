FROM ubuntu:14.04
FROM ruby:3.0.1

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

RUN mkdir -p /getcovered
WORKDIR /getcovered

COPY Gemfile /getcovered
COPY  Gemfile.lock /getcovered
RUN bundle install

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000
CMD ["bundle", "exec", "sidekiq"]
