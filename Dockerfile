FROM gitlab/gitlab-ce:10.8.3-ce.0

RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    g++ \
    gcc \
    cron \
    make \
    cmake \
    pkg-config \
    ruby-mysql \
    mysql-client \
    ruby-dev \
    libpq-dev \
    libicu-dev \
    libre2-dev \
    libmysqlclient-dev

RUN curl -sSL https://rvm.io/mpapis.asc | gpg2 --import - && curl -L get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements && rvm install 2.3.7 && rvm use 2.3.7 && gem install bundler"
RUN /bin/bash -l -c "cd /opt/gitlab/embedded/service/gitlab-rails && \
                     rm -rf .bundle/config && \
                     bundle install --deployment --without development test aws kerberos"
COPY entrypoint.sh .
# 配置自定义的oauth2认证
COPY customize_oauth.rb /opt/gitlab/embedded/service/gitlab-rails/config/initializers/
CMD [ "bash","entrypoint.sh" ]