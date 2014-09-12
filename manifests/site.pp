# == Define: nginx::site
#
# Provisions an Nginx vhost. Like file resources, this resource type takes
# either a 'content' parameter with a string literal value or or 'source'
# parameter with a Puppet file reference. The resource title is used as the
# site name.
#
# === Parameters
#
# [*content*]
#   The Nginx site configuration as a string literal.
#   Either this or 'source' must be set.
#
# [*source*]
#   The Nginx site configuration as a Puppet file reference.
#   Either this or 'content' must be set.
#
# [*ensure*]
#   'present' or 'absent'; whether the site configuration is
#   installed or removed in sites-available/
#
# [*enabled*]
#   Boolean; true by default.
#
# === Examples
#
#  nginx::site { 'graphite':
#    content => template('graphite/graphite.nginx.erb'),
#  }
#
define nginx::site(
    $content = undef,
    $source  = undef,
    $ensure  = present,
    $enabled = true,
)
{
    include ::nginx

    $basename = regsubst($title, '\W', '-', 'G')

    file { "/etc/nginx/sites-available/${basename}":
        content => $content,
        source  => $source,
        ensure  => $ensure
    }

    if $ensure == 'present' and $enabled == true {
        file { "/etc/nginx/sites-enabled/${basename}":
            require => File["/etc/nginx/sites-available/${basename}"],
            ensure  => link,
            target  => "/etc/nginx/sites-available/${basename}",
        }
    }
    else {
        file { "/etc/nginx/sites-enabled/${basename}":
            ensure => absent
        }
    }
}
