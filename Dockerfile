FROM gitlab/gitlab-ce:10.2.8-ce.0

RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    g++ \
    make \
    cmake \
    libmysqlclient-dev \
    ruby-mysql \
    mysql-client \
    gcc \
    cron

RUN /opt/gitlab/embedded/bin/gem install mysql2 -v '0.4.5' -- --with-mysql-lib=/usr/lib64/mysql

RUN cd /opt/gitlab/embedded/service/gitlab-rails && \
    rm -rf .bundle && \
    gem install charlock_holmes -v '0.7.5' && \
    /opt/gitlab/embedded/bin/bundle install --deployment --without development test aws kerberos

COPY entrypoint.sh .
# 配置自定义的oauth2认证
COPY customize_oauth.rb /opt/gitlab/embedded/service/gitlab-rails/config/initializers/
CMD [ "bash","entrypoint.sh" ]