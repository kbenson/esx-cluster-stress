#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use IO::Socket;
use Time::HiRes;
use LWP::UserAgent;
$|=1;

use threads (
    'yield',
    'stack_size' => 64*4096,
    'exit' => 'threads_only',
    'stringify'
);
use threads::shared;

my $QUIT :shared;
$SIG{INT} = \&quit;
my %base_stats = ( remote_addr=>'UNSET', last_send=>'UNSET', last_recv=>'UNSET', last_success=>undef, note=>'' );
my @servers_list = find_servers();
my %servers_data;
my @threads;
for my $server_addr ( @servers_list ) {
    warn "Adding shared data for server $server_addr" if $ENV{DEBUG};
    $servers_data{$server_addr} = shared_clone({ %base_stats, remote_addr=>$server_addr });
    push @threads, threads->create(\&start_client, $server_addr);
}

while ( 1 ) {
    warn "... starting report" if $ENV{DEBUG};
    my $start = Time::HiRes::time;
    say '#' x 40;
    say "Servers report for " . localtime;
    for my $server_addr ( @servers_list ) {
        warn "... locking $server_addr" if $ENV{DEBUG};
        my $lst = do { lock($servers_data{$server_addr}); $servers_data{$server_addr}{last_success} };
        warn "... locked $server_addr" if $ENV{DEBUG};
        my $last_success = $lst ? sprintf("%0.2f seconds ago", Time::HiRes::time - $lst) : "NEVER";
        warn "... reporting $server_addr" if $ENV{DEBUG};
        say sprintf "  %-15s  succeeded as of %s", $server_addr, $last_success;
    }
    printf "Done reporting (%0.2fs elapsed)\n", Time::HiRes::time - $start;

    my $last;
    { lock($QUIT); $last++ if $QUIT }
    last if $last;

    my $report_time = Time::HiRes::time - $start;
    Time::HiRes::sleep( 1 - $report_time ) if $report_time < 1;
}

warn "Joining threads for exit...";
$_->join for @threads;

exit;

# SUBS BELOW!

sub find_servers {
    return split /\s*,\s*/, $ENV{SERVERLIST} if $ENV{SERVERLIST};
    my $servers_url = 'http://192.168.1.10/servers';
    warn "Finding servers to use from $servers_url";
    my $response = LWP::UserAgent->new->get($servers_url);
    die "Error finding servers: " . $response->status_line unless $response->is_success;
    my @servers = $response->decoded_content =~ /IP: ([\d.]+),/gsmi;
    warn "Found servers: " . join ", ", @servers;
    return @servers;
}

sub start_client {
    my $server_addr = shift or die "No server addr passed";
    my $server = IO::Socket::INET->new(
        PeerAddr    => $server_addr,
        PeerPort    => 10001,
        Proto       =>'tcp',
        Type        => SOCK_STREAM,
    ) or die "Error starting TCP server: $@";
    my $banner = <$server>;
    die "Bad server banner: $banner" unless $banner =~ /^WELCOME/;

    client_loop($server,$server_addr);
}

sub client_loop {
    my $server = shift or die "No server passed";
    my $server_addr = shift or die "No server_addr passed";
    my $count = 0;
    while (++$count) {
        my $time = localtime;
        my $send = "($count) " . localtime;
        $server->send("$send\n");
        warn ",,, locking $server_addr" if $ENV{DEBUG};
        {
            my $data = lock($servers_data{$server_addr});
            $data->{last_send} = $send;
        }
        warn ",,, locked $server_addr" if $ENV{DEBUG};

        my $recv = <$server>;
        $recv =~ s/[\r\n]$//g;
        warn ",,, locking $server_addr" if $ENV{DEBUG};
        {
            my $data = lock($servers_data{$server_addr});
            $data->{last_recv} = $recv;
            if ( $send eq $recv ) {
                $data->{last_success} = Time::HiRes::time;
                $data->{note} = '' if length($data->{note});
            }
            else {
                my $err = "Error: send did not match recv: $send != $recv";
                warn $err;
                $data->{note} = $err;
            }
        }
        warn ",,, locked $server_addr" if $ENV{DEBUG};

        my $disconnect;
        { lock($QUIT); $disconnect++ if $QUIT }
        if ( $disconnect ) {
            $server->send("QUIT\n");
            return;
        }

        Time::HiRes::sleep(0.4);
    }
}

sub quit {
    warn "SIGINT RECEIVED";
    alarm(5);
    { lock($QUIT); $QUIT = 1; }
}
