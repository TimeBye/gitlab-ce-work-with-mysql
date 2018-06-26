FROM gitlab/gitlab-ce:10.8.5-ce.0

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
RUN /bin/bash -l -c "rvm requirements && rvm install 2.3.7 && rvm use 2.3.7 && gem install bundler --no-ri --no-rdoc"
RUN /bin/bash -l -c "cd /opt/gitlab/embedded/service/gitlab-rails && \
                     rm -rf .bundle/config && \
                     bundle install --deployment --without development test aws kerberos"
# Issues https://gitlab.com/gitlab-org/gitlab-ce/issues/43514
RUN sed -i 's/create_table.*/create_table :lfs_file_locks, options: '"'ROW_FORMAT=DYNAMIC'"' do |t|/' /opt/gitlab/embedded/service/gitlab-rails/db/migrate/20180116193854_create_lfs_file_locks.rb
COPY entrypoint.sh .
# 配置自定义的oauth2认证
COPY customize_oauth.rb /opt/gitlab/embedded/service/gitlab-rails/config/initializers/
# 修改默认时区
# RUN cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
CMD [ "bash","entrypoint.sh" ]