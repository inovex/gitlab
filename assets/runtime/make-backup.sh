#!/bin/bash -e

start=$(date +%s)

# Run the actual backup
ulimit -n 500000
cd ${GITLAB_INSTALL_DIR}
bundle exec rake gitlab:backup:create SKIP= RAILS_ENV=production
rc=$?

end=$(date +%s)

# Size of the newest backup tar file
size=$(find ${GITLAB_BACKUP_DIR?} -name '*_gitlab_backup.tar' -printf "%T@ %s\n" | sort -n | tail -n 1 | awk '{print $2}')

#TODO: Report size of tar on S3

# Write to a temporary file invisible to premetheus
cat > ${GITLAB_METRICS_DIR?}/gitlab_backup_rake.prom <<EOT
# HELP gitlab_rake_backup_create_start backup start time, in unixtime.
# TYPE gitlab_rake_backup_create_start gauge
gitlab_rake_backup_create_start ${start?}
# HELP gitlab_rake_backup_create_end backup end time, in unixtime.
# TYPE gitlab_rake_backup_create_end gauge
gitlab_rake_backup_create_end ${end?}
# HELP gitlab_rake_backup_create_size backup size, in bytes.
# TYPE gitlab_rake_backup_create_size gauge
gitlab_rake_backup_create_size ${size?}
# HELP gitlab_rake_backup_create_exitcode exitcode of rake task.
# TYPE gitlab_rake_backup_create_exitcode gauge
gitlab_rake_backup_create_exitcode ${rc?}
EOT

exit ${rc?}
