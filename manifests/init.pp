# dispatcher
#
# Installs and configures the AEM Dispatcher module
#
# @summary Install the Apache AEM Dispatcher module and configure the module. If provided also the farms will be configured.
#
# @example Minimal example
#   include apache
#
#   class { 'dispatcher':
#     module_file => '/path/to/dispatcher-apache.so'
#   }
# @param ensure Changes the state of the dispatcher configuration. Valid options: present or absent. Default: present.
# @param module_file Specifies which dispatcher module will be loaded. Valid options: any absolute path to file.
# @param config_file Name of the dispatcher farm any file. Default: dispatcher.farms.any.
# @param decline_root Sets the DispatcherDelcineRoot value for the dispatcher configuration. Valid options: 0, 1, off or on. Default: off.
# @param dispatcher_name Sets the name of the dispatcher in the root dispatcher farm file. Valid options: any string.
# @param farm_path Apache configuration directory for the dispatcher. Default: Apache's configuration directory.
# @param group Sets the group for file ownership. Valid options: any valid group. Default: Apache's root group.
# @param log_file Sets the name and location of the dispatcher log file. Valid options: any fully qualified file name. Default: /dispatcher.log.
# @param log_level Sets the log level for dispatcher logging. Valid options: 0, 1, 2, 3, 4, error, warn, info, debug, trace. Default: warn.
# @param mod_path Required. Specifies which dispatcher module will be loaded. Valid options: any absolute path to file.
# @param no_server_header Sets the DispatcherNoServerHeader value for the dispatcher configuration. Valid options: 0, 1, off or on. Default: off.
# @param pass_error Sets the DispatcherPassError value for the dispatcher configuration. Valid options: any string. Default: 0.
# @param use_processed_url Sets the DispatcherUseProcessedURL value for the dispatcher configuration. Valid options: 0, 1, off or on. Default: off.
# @param user Sets the user for file ownership. Valid options: any valid user. Default: root.
class dispatcher (
  Enum['present', 'absent'] $ensure,
  Stdlib::Absolutepath $module_file,
  String $config_file,
  Variant[Enum['on', 'off'], Integer[0, 1]] $decline_root,
  Optional[String] $dispatcher_name,
  String $farm_path,
  String $group,
  Stdlib::Absolutepath $log_file,
  Variant[Enum['error', 'warn', 'info', 'debug', 'trace'], Integer[0,4]] $log_level,
  Stdlib::Absolutepath $mod_path,
  Variant[Enum['on', 'off'], Integer[0, 1]] $no_server_header,
  Variant[String, Integer] $pass_error,
  Variant[Enum['on', 'off'], Integer[0, 1]] $use_processed_url,
  String $user,
) {

  # Check for Apache because it is used by parameter defaults
  if ! defined(Class['apache']) {
    fail('You must include the apache base class before using any dispatcher class or defined resources')
  }

  $_mod_filename = basename($module_file)

  # Manage actions
  if ($ensure == 'present') {

    apache::mod { 'dispatcher' :
      lib => 'mod_dispatcher.so',
    }

    file { "${::dispatcher::mod_path}/${_mod_filename}" :
      ensure  => file,
      group   => $group,
      owner   => $user,
      replace => true,
      source  => $module_file,
    }

    file { "${::dispatcher::mod_path}/mod_dispatcher.so" :
      ensure  => link,
      group   => $group,
      owner   => $user,
      replace => true,
      target  => "${::dispatcher::mod_path}/${_mod_filename}",
    }

    file { "${::dispatcher::farm_path}/dispatcher.conf" :
      ensure  => file,
      group   => $group,
      owner   => $user,
      replace => true,
      content => template("${module_name}/dispatcher.conf.erb")
    }

    file {  "${::dispatcher::farm_path}/${config_file}":
      ensure  => file,
      group   => $group,
      owner   => $user,
      replace => true,
      content => template("${module_name}/dispatcher.farms.erb")
    }

    if $facts['selinux'] {

      File["${::dispatcher::mod_path}/${_mod_filename}"] {
        seltype => 'httpd_modules_t',
      }

      File["${::dispatcher::mod_path}/mod_dispatcher.so"] {
        seltype => 'httpd_modules_t',
      }

      selboolean { 'httpd_can_network_connect':
        value      => 'on',
        persistent => true,
      }

    }

    File["${::dispatcher::mod_path}/${_mod_filename}"]
    -> File["${::dispatcher::mod_path}/mod_dispatcher.so"]
    -> Apache::Mod['dispatcher']
    -> File["${::dispatcher::farm_path}/${config_file}"]
    -> File["${::dispatcher::farm_path}/dispatcher.conf"]

  }
  else {

    file { "${::dispatcher::mod_path}/${_mod_filename}" :
      ensure => $ensure,
    }

    file { "${::dispatcher::mod_path}/mod_dispatcher.so" :
      ensure => $ensure,
    }

    file { "${::dispatcher::farm_path}/dispatcher.conf" :
      ensure => $ensure,
    }

    file { "${::dispatcher::farm_path}/${config_file}" :
      ensure => $ensure,
    }

    File["${::dispatcher::farm_path}/dispatcher.conf"]
    -> File["${::dispatcher::farm_path}/${config_file}"]
    -> File["${::dispatcher::mod_path}/${_mod_filename}"]
    -> File["${::dispatcher::mod_path}/mod_dispatcher.so"]

  }

  if defined(Service[$::apache::service_name]) {

    File["${::dispatcher::farm_path}/${config_file}"]
    ~> Service[$::apache::service_name]

    File["${::dispatcher::farm_path}/dispatcher.conf"]
    ~> Service[$::apache::service_name]

  }

}