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

    package { [ "nginx-${variant}", 'nginx-common' ]: }

    # In the unmanaged case, this prevents the scenario where after the
    # initial puppet run that installs the package, the net resulting state is
    # a fully deployed configuration on disk, but the running instance still
    # running the default configuration from the package.  With this, it gets
    # stopped before the service clause checks->starts it with good config.
    if ! $managed {
        exec { 'stop-default-nginx':
            command     => '/usr/sbin/service nginx stop',
            subscribe   => Package["nginx-${variant}"],
            refreshonly => true,
            before      => Service['nginx'],
        }
    }

    service { 'nginx':
        ensure     => running,
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
    }

    file { [ '/etc/nginx/conf.d', '/etc/nginx/sites-available', '/etc/nginx/sites-enabled' ]:
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
        tag     => 'nginx', # workaround PUP-2689, can remove w/ puppetmaster 3.6.2+
    }

    # Order package -> config -> service for all
    #  nginx-tagged config files (including all File resources
    #  declared within this module), and set up the
    #  notification for config~>service if $managed.
    # Also set up ssl tag -> service similarly, for certs
    Package["nginx-${variant}"] -> File <| tag == 'nginx' |>
    if $managed {
        File <| tag == 'nginx' |> ~> Service['nginx']
        File <| tag == 'ssl' |> ~> Service['nginx']
    }
    else {
        File <| tag == 'nginx' |> -> Service['nginx']
        File <| tag == 'ssl' |> -> Service['nginx']
    }

    # The jessie conditional here is just to limit the changes to
    #  new reinstalls under examination without disturbing the
    #  running precise machines - can be removed later, is not real.
    if os_version('debian >= jessie') and $::realm == 'production' {
        # nginx will buffer e.g. large body content into this directory
        #  very briefly, so keep it off the disks.
        mount { '/var/lib/nginx':
            ensure  => mounted,
            device  => 'tmpfs',
            fstype  => 'tmpfs',
            options => 'defaults,noatime,uid=0,gid=0,mode=755,size=1g',
            pass    => 0,
            dump    => 0,
            before  => Service['nginx'],
            require => Package["nginx-${variant}"],
        }
    }
}
