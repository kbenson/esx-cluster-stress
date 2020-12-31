# Installation

Have perl.  Have cpanm.  have sqlite libs. Clone repo.

Run ./setup.sh in repo to install required perl libs.

# Configuration

## Controller VM

Note: If there are any worries about selinux, turn it off in the VMs.

1. Configure VM with static IP.  Note it.  We'll use 192.168.1.10 as example.
2. Set params in esx-cluster-stress.conf for controller:
    role => {
      server => 0,
      client => 0,
      controller => 1,
    },
3. Start manually or set to start at boot.

## Server template

1. Configure VM with DHCP IP.
2. Set params in esx-cluster-stress.conf for server:
    role => {
      server => 1,
      client => 0,
      controller => 0,
    },
    controller => 'http://192.168.1.10',
    where the controller address has the IP to access the controller.
3. Set to start at boot.
4. Make esx-cluster-stress-server template from VM.

## Client template

1. Configure VM with DHCP IP.
2. Set params in esx-cluster-stress.conf for server:
    role => {
      server => 0,
      client => 1,
      controller => 0,
    },
    controller => 'http://192.168.1.10',
   where the controller address has the IP to access the controller.
3. Set to start at boot.
4. Make esx-cluster-stress-client template from VM.

# Running

Make sure controller VM is running.

Create VM from appropriate template.  It will register itself with the
controller if it's a server, and get a list of servers to query if it's
a client.

Note: This all assumes the controller sees traffic from the real IPs of
the servers.  Currently it assumes port 80 of the source IP.  To be safe,
put the controller and all clients/servers into the same zone/range
without NAT between them,

# Development

To install a module to use with this, use:

    cpanm -L extlib $MODULE

as that will install any non-core module even if it exists in perl's
path if it isn't in that module directory.  Keeps us from having to
know what's installed on the target box.  Make sure to add to setup.sh.

To rebuild for a different dist, since this is based on centos 7,
reinstall the requirements:

    cpanm -L extlib --reinstall CryptX
    cpanm -L extlib --reinstall DBD::SQLite

Mojolicious should be pure perl so it shouldn't need reinstall, but
if it does, you can reinstall it like above.

You can always remove all of extlib and run ./setup.sh again to build
all requirements from scrach.

# TODO

Add disk stressing component for client and/or servers.  Maybe generate
1MB chunk of random data and use 'generate' param to grab a number of
random chunks in it and 'want' param to control network data?

