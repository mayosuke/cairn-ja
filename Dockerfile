# Ruby 3.3.12 / Debian 13, pinned to the image used by cairn-en-dev.
FROM ruby:3.3@sha256:a91b6ac1b9b18d33812480856e4bc39c5c492ff9c6cc810d916cc3f0cc1d0eab

ENV BUNDLE_FROZEN=true \
    BUNDLE_PATH=/usr/local/bundle \
    JEKYLL_ENV=docker

WORKDIR /source
RUN gem install bundler --version 4.0.14 --no-document
COPY Gemfile Gemfile.lock ./
RUN bundle _4.0.14_ install && bundle _4.0.14_ check
COPY docker/jekyll-dev.yml /opt/cairn/jekyll-dev.yml
COPY docker/entrypoint.sh /opt/cairn/entrypoint.sh

EXPOSE 4000 35729
CMD ["sh", "/opt/cairn/entrypoint.sh"]
