#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use IO::Socket;
use Time::HiRes;
$|=1;
$SIG{CHLD} = 'IGNORE';

my $server = IO::Socket::INET->new(
    LocalPort   => 10001,
    Proto       => 'tcp',
    Type        => SOCK_STREAM,
    Reuse       => 1,
    Listen      => 20,
) or die "Error starting TCP server: $@";

while (my ($client) = $server->accept()) {
    my $client_addr = $client->peerhost;
    my $child_pid = fork;
    if ( not defined $child_pid ) {
        warn "Error forking child: $!";
    }
    # Parent
    if ( $child_pid ) {
        warn "Forked child for connection from $client_addr with PID $child_pid";
    }
    else {
        &stream($server, $client, $client_addr);
    }
}

exit;

sub stream {
    my ($server,$client,$client_addr) = @_;
    $SIG{__DIE__} = sub { warn "Child $$ for $client_addr exited" };
    my $randid = join "", map { chr(97+rand(26)) } (1..4);
    $client->send("WELCOME $client_addr ($randid)\n");
    my $count = 0;
    my $last = 'NONE';
    my $start = Time::HiRes::time;
    while (++$count) {
        my $client_in = <$client>;
        $client_in =~ s/[\r\n]$//g;
        last if uc($client_in) eq 'QUIT';
        $start += 1;
        $client->send("$client_in\n");
        say "($client_addr / $randid / $count): $client_in (".length($client_in).")";
    }
    $client->send("GOODBYE");
    say "Client $client_addr ended session";
}

