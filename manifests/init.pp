# ssh/manifests/init.pp - common ssh related components
# Copyright (C) 2007 David Schmitt <david@schmitt.edv-bus.at>
# See LICENSE for the full license granted to you.


class ssh_base {
	file {
		"/etc/ssh":
			ensure => directory, mode => 0755;
		"$rubysitedir/facter/sshkeys.rb":
			#content => file("$modulesdir/facter/sshkeys.rb"),
			source => "puppet://$servername/ssh/facter/sshkeys.rb",
			mode => 0644;
	}
}

class ssh_client inherits ssh_base {
	package { "openssh-client":
		ensure => installed,
		before => File["/etc/ssh"]
	}
	
	# Now collect all server keys
	Sshkey <<||>>
}

class sshd inherits ssh_base {

	# every server is a client too
	include ssh_client

	package { "openssh-server": ensure => installed }

	service { ssh:
		ensure => running,
		pattern => "sshd",
		require => Package["openssh-server"],
	}

	# Now add the key, if we've got one
	case $sshrsakey_key {
		"": { 
			err("no sshrsakey on $fqdn")
		}
		default: {
			#@@sshkey { "$hostname.$domain": type => ssh-dss, key => $sshdsakey_key, ensure => present, }
			debug ( "Storing rsa key for $hostname.$domain" )
			@@sshkey { "$hostname.$domain": type => ssh-rsa, key => $sshrsakey_key, ensure => present }
		}
	}

	$real_ssh_port = $ssh_port ? { '' => 22, default => $ssh_port }

	config{ "Port": ensure => $real_ssh_port }

	nagios2::service{ "ssh_port_${real_ssh_port}": check_command => "ssh_port!$real_ssh_port" }

	define config($ensure) {
		replace { "sshd_config_$name":
			file => "/etc/ssh/sshd_config",
			pattern => "^$name +(?!\\Q$ensure\\E).*",
			replacement => "$name $ensure # set by puppet",
			notify => Service[ssh],
		}
	}

}

