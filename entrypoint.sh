#!/bin/bash

set -e

GITLAB_BACKUP_EXPIRY=${GITLAB_BACKUP_EXPIRY:-"604800"}
GITLAB_BACKUP_SCHEDULE=${GITLAB_BACKUP_SCHEDULE:-"disable"}
RAILS_ENV=${RAILS_ENV:-"production"}
GITLAB_BACKUP_SKIP=${GITLAB_BACKUP_SKIP:-"builds"}

function gitlab_configure_time_zone() {
    TZ=${TZ:-"Asia/Shanghai"}
    echo $TZ > /etc/timezone
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
}

function gitlab_configure_backups_expiry() {
    service cron restart
    if [[ -e /etc/gitlab/gitlab.rb ]]; then
        if [[ `grep -o "backup_keep_time" /etc/gitlab/gitlab.rb | wc -l` -eq 0 ]]; then
            echo "gitlab_rails['backup_keep_time'] = ${GITLAB_BACKUP_EXPIRY}" >> /etc/gitlab/gitlab.rb
        fi
        sed -i "s/.*backup_keep_time.*/gitlab_rails['backup_keep_time'] = ${GITLAB_BACKUP_EXPIRY}/g" /etc/gitlab/gitlab.rb
    else
        sed -i "s/.*backup_keep_time.*/gitlab_rails['backup_keep_time'] = ${GITLAB_BACKUP_EXPIRY}/g" /opt/gitlab/etc/gitlab.rb.template
    fi
}

function gitlab_configure_backups_schedule() {
    case ${GITLAB_BACKUP_SCHEDULE} in
        daily|weekly|monthly)
            gitlab_configure_backups_expiry
            GITLAB_BACKUP_TIME=${GITLAB_BACKUP_TIME:-"04:00"}
            if ! crontab -u `whoami` -l >/tmp/cron.`whoami` 2>/dev/null || ! grep -q 'gitlab:backup:create' /tmp/cron.`whoami`; then
                echo "Configuring gitlab::backups::schedule..."
                min=${GITLAB_BACKUP_TIME#*:}
                hour=${GITLAB_BACKUP_TIME%:*}
                day_of_month=*
                month=*
                day_of_week=*
                case ${GITLAB_BACKUP_SCHEDULE} in
                    daily) ;;
                    weekly) day_of_week=0 ;;
                    monthly) day_of_month=01 ;;
                esac
                echo "$min $hour $day_of_month $month $day_of_week gitlab-rake gitlab:backup:create SKIP=${GITLAB_BACKUP_SKIP} RAILS_ENV=${RAILS_ENV}" >> /tmp/cron.`whoami`
                crontab -u `whoami` /tmp/cron.`whoami`
            fi
            rm -rf /tmp/cron.`whoami`
        ;;
        advanced)
            gitlab_configure_backups_expiry
            if ! crontab -u `whoami` -l >/tmp/cron.`whoami` 2>/dev/null || ! grep -q 'gitlab:backup:create' /tmp/cron.`whoami`; then
                echo "${GITLAB_BACKUP_TIME:-"00 04 * * *"} gitlab-rake gitlab:backup:create SKIP=${GITLAB_BACKUP_SKIP} RAILS_ENV=${RAILS_ENV}" >> /tmp/cron.`whoami`
                crontab -u `whoami` /tmp/cron.`whoami`
            fi
            rm -rf /tmp/cron.`whoami`
        ;;
    esac
}

# Copy gitlab.rb for the first time
if [[ -e /opt/choerodon/paas/etc/gitlab.rb ]]; then
	echo "Installing configmap gitlab.rb config..."
	cp -f /opt/choerodon/paas/etc/gitlab.rb /etc/gitlab/gitlab.rb
	chmod 0600 /etc/gitlab/gitlab.rb
fi

gitlab_configure_time_zone
gitlab_configure_backups_schedule
/assets/wrapper