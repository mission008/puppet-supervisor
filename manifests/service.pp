# Actions:
#   Set up a daemon to be run by supervisor
#
# Sample Usage:
#  supervisor::service { 'organizational_worker':
#    command         => '/usr/bin/php /var/www/vhosts/site/gearman/worker.php',
#    numprocs        => 2,
#    numprocs_start  => 1,
#    user            => 'org_user',
#    group           => 'org_group',
#  }
#
define supervisor::service (
  $command,
  $ensure                   = present,
  $numprocs                 = 1,
  $numprocs_start           = 0,
  $priority                 = 999,
  $autorestart              = 'unexpected',
  $startsecs                = 1,
  $retries                  = 3,
  $exitcodes                = '0,2',
  $stopsignal               = 'TERM',
  $stopwait                 = 10,
  $stopasgroup              = false,
  $killasgroup              = false,
  $user                     = 'root',
  $group                    = 'root',
  $redirect_stderr          = false,
  $directory                = undef,
  $stdout_logfile           = undef,
  $stdout_logfile_maxsize   = '250MB',
  $stdout_logfile_keep      = 10,
  $stderr_logfile           = undef,
  $stderr_logfile_maxsize   = '250MB',
  $stderr_logfile_keep      = 10,
  $environment              = undef,
  $umask                    = undef
) {
  case $ensure {
    absent: {
      $autostart = false
      $dir_ensure = 'absent'
      $dir_recurse = true
      $dir_force = true
      $service_ensure = 'stopped'
      $config_ensure = 'absent'
    }
    present: {
      $autostart = true
      $dir_ensure = 'directory'
      $dir_recurse = false
      $dir_force = false
      $service_ensure = 'running'
      $config_ensure = file
    }
    default: {
      fail("ensure must be 'present' or 'absent', not ${ensure}")
    }
  }

  if $numprocs > 1 {
    $process_name = "${name}:*"
  } else {
    $process_name = $name
  }

  # logs:

  file { "${supervisor::childlogdir}/${name}":
    ensure  => $dir_ensure,
    owner   => $user,
    group   => $group,
    mode    => '0750',
    recurse => $dir_recurse,
    force   => $dir_force,
    require => File[$supervisor::childlogdir],
  }

  # svc config / ini-file:

  $conf_file = "${supervisor::conf_dir}/${name}${supervisor::conf_ext}"

  file { $conf_file:
    ensure  => $config_ensure,
    content => template('supervisor/service.ini.erb'),
    require => File[$supervisor::conf_dir],
  }

  service { "supervisor::${name}":
    ensure   => $service_ensure,
    provider => supervisor,
  }

  # update supervisord to changes with the configuration file

  File[$conf_file] ~>

  exec { "exec-update-${conf_file}":
    command     => '/usr/bin/supervisorctl update',
    logoutput   => on_failure,
    refreshonly => true,
  }

  if $ensure == 'present' {
    Exec['supervisor::update'] ~> Service["supervisor::${name}"]
  } else {
    # First stop the service, delete the .ini, reload the config, delete the log dir
    Service["supervisor::${name}"] -> File[$conf_file]
    Exec['supervisor::update'] -> File["${supervisor::childlogdir}/${name}"]
  }
}
