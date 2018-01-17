# dispatcher::farm
#
# Defenis a farm configuration
#
# @summary Set a farm configuration that is included in the dispatcher any file.
#
# @example Minimal example
#   dispatcher::farm { 'site':
#     docroot => '/var/www/html'
#   }
#
# @param docroot Sets the cache /docroot rule.
# @param allow_authorized Sets the cache /allowAuthorized rule.
# @param allowed_clients Sets the cache /allowedClients section.
# @param cache_headers Sets the cache /headers section.
# @param cache_rules Sets the cache /rules section.
# @param cache_ttl Sets the cache /enableTTL rule.
# @param client_headers  Sets the /clientheaders rule.
# @param ensure Changes the state of the dispatcher farm configuration. Valid options: present or absent.
# @param failover Sets the /failover rule.
# @param filters Sets the /fiters section.
# @param grace_period Sets the cache /grace rule.
# @param health_check_url Sets the cache /ignoreUrlParams section.
# @param ignore_parameters Sets the cache /ignoreUrlParams section.
# @param invalidate Sets the cache /invalidate section.
# @param invalidate_handler Sets the cache /invalidateHandler rule.
# @param priority Defines a priority for the resulting farm configuration to be included in the global dispatcher farm configuration. Farms with a lower priority will be included first. Farms with the same priority will be included in alphabetical order.
# @param propagate_synd_post Sets the /propagateSyndPost rule.
# @param renders Sets the /renders section.
# @param retries Sets the /numberOfRetries rule.
# @param retry_delay Sets the /retryDelay rule.
# @param serve_stale Sets the cache /serveStaleOnError rule.
# @param session_management Sets the /sessionmanagement section.
# @param stat_file Sets the cache /statfile rule.
# @param stat_files_level Sets the cache /statfileslevel rule.
# @param statistics Sets the /statistics section.
# @param sticky_connections Sets the /stickyConnectionsFor rule or /stickyConnectionsFor section based on value.
# @param unavailable_penalty Sets the /unavailablePenalty rule.
# @param vanity_urls Sets the /vanity_urls section.
# @param virtualhosts Sets the /virtualhosts section.
define dispatcher::farm(
  Enum['present', 'absent'] $ensure = lookup('dispatcher::farm::ensure'),
  Stdlib::Absolutepath $docroot,
  Optional[Integer[0, 1]] $allow_authorized = lookup('dispatcher::farm::allow_authorized'),
  Array[Hash] $allowed_clients = lookup('dispatcher::farm::allowed_clients'),
  Optional[Array[String]] $cache_headers = lookup('dispatcher::farm::cache_headers'),
  Array[Hash] $cache_rules = lookup('dispatcher::farm::cache_rules'),
  Optional[Integer[0, 1]] $cache_ttl = lookup('dispatcher::farm::cache_ttl'),
  Array[String] $client_headers = lookup('dispatcher::farm::client_headers'),
  Optional[Integer[0, 1]] $failover = lookup('dispatcher::farm::failover'),
  Array[Hash] $filters = lookup('dispatcher::farm::filters'),
  Optional[Integer[1]] $grace_period = lookup('dispatcher::farm::grace_period'),
  Optional[String] $health_check_url = lookup('dispatcher::farm::health_check_url'),
  Optional[Array[Hash]] $ignore_parameters = lookup('dispatcher::farm::ignore_parameters'),
  Optional[Array[Hash]] $invalidate = lookup('dispatcher::farm::invalidate'),
  Optional[Stdlib::Absolutepath] $invalidate_handler = lookup('dispatcher::farm::invalidate_handler'),
  Integer[0, 99] $priority = lookup('dispatcher::farm::priority'),
  Optional[Integer[0, 1]] $propagate_synd_post = lookup('dispatcher::farm::propagate_synd_post'),
  Array[Hash] $renders = lookup('dispatcher::farm::renders'),
  Optional[Integer[1]] $retries = lookup('dispatcher::farm::retries'),
  Optional[Integer[1]] $retry_delay = lookup('dispatcher::farm::retry_delay'),
  Optional[Integer[0, 1]] $serve_stale = lookup('dispatcher::farm::serve_stale'),
  Optional[Hash] $session_management = lookup('dispatcher::farm::session_management'),
  Optional[Stdlib::Absolutepath] $stat_file = lookup('dispatcher::farm::stat_file'),
  Optional[Integer[0]] $stat_files_level = lookup('dispatcher::farm::stat_files_level'),
  Optional[Array[Hash]] $statistics = lookup('dispatcher::farm::statistics'),
  Optional[Array[String]] $sticky_connections = lookup('dispatcher::farm::sticky_connections'),
  Optional[Integer[1]] $unavailable_penalty = lookup('dispatcher::farm::unavailable_penalty'),
  Optional[Hash] $vanity_urls = lookup('dispatcher::farm::vanity_urls'),
  Array[String] $virtualhosts = lookup('dispatcher::farm::virtualhosts'),
) {

  # Required dispatcher class because it is used by parameter defaults
  if ! defined(Class['::dispatcher']) {
    fail('You must include the dispatcher base class before using any dispatcher class or defined resources')
  }

  if $invalidate and $invalidate_handler {
    fail('Both invalidate and invalidate_handler can not be set.')
  }

  if $priority < 10 {
    $priority_string = "0${priority}"
  }
  else {
    $priority_string = $priority
  }

  if $session_management {
    if $allow_authorized == 1 {
      fail('Allow authorized and session management are mutually exclusive.')
    }
    if !has_key($session_management, 'directory') {
      fail('Session management directory is not specified.')
    }
    else {
      validate_absolute_path($session_management['directory'])
    }
    if has_key($session_management, 'encode') {
      validate_re($session_management['encode'], '^(md5|hex)$',
        "${session_management['encode']} is not supported for session_management['encode']. Allowed values are 'md5' and 'hex'.")
    }
    if has_key($session_management, 'timeout') {
      validate_integer($session_management['timeout'], undef, 0)
    }
  }

  if $vanity_urls {
    if !has_key($vanity_urls, 'file') {
      fail('Vanity Urls cache file is not specified.')
    }
    else {
      validate_absolute_path($vanity_urls['file'])
      validate_integer($vanity_urls['delay'], undef, 0)
    }
  }

  if $ensure == 'present' {
    file { "${::dispatcher::farm_path}/dispatcher.${priority_string}-${name}.inc.any" :
      ensure  => $ensure,
      content => template("${module_name}/dispatcher.any.erb"),
      notify  => Service[$::apache::service_name],
    }
  }
  else {
    file { "${::dispatcher::farm_path}/dispatcher.${priority_string}-${name}.inc.any" :
      ensure => $ensure,
      notify => Service[$::apache::service_name],
    }
  }

}
