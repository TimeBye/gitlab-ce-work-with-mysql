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

RUN cd /opt/gitlab/embedded/service/gitlab-rails && \
    rm -rf .bundle && \
    /opt/gitlab/embedded/bin/bundle install --deployment --without development test aws kerberos

COPY entrypoint.sh .
# 配置自定义的oauth2认证
COPY customize_oauth.rb /opt/gitlab/embedded/service/gitlab-rails/config/initializers/
CMD [ "bash","entrypoint.sh" ]