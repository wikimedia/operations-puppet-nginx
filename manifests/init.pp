# == Class: nginx
#
# Nginx is a popular, high-performance HTTP server and reverse proxy.
# This module is very small and simple, providing an 'nginx::site' resource
# type that takes an Nginx configuration file as input.
#
# This also installs the nginx-common package by default explicitly, so
# other code can require that package to do things after install but potentially
# before the service starts.
#
# === Parameters
#
# [*managed*]
#   If true (the default), changes to Nginx configuration files and site
#   definition files will trigger a restart of the Nginx server. If
#   false, the service will need to be manually restarted for the
#   configuration changes to take effect.
#
# [*variant*]
#   Which variant of the nginx package to install. Must be one of
#   'full', 'light' or 'extras', which respectively install one of
#   'nginx-full', 'nginx-light' or 'nginx-extras' packages.
#
class nginx(
    $managed = true,
    $variant = 'full',
)
{
    if $variant !~ /^(full|extras|light$)/ {
        fail("'variant' must be 'full', 'extras', or 'light' (got: '${variant}').")
    }

    package { [ "nginx-${variant}", "nginx-${variant}-dbg", 'nginx-common' ]: }

    service { 'nginx':
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
        require    => Package["nginx-${variant}"],
    }

    file { [ '/etc/nginx/conf.d', '/etc/nginx/sites-available', '/etc/nginx/sites-enabled' ]:
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
        require => Package["nginx-${variant}"],
    }

    if $managed {
        File <| tag == 'nginx' |> ~> Service['nginx']
    }
}
