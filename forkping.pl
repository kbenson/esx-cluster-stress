#!/usr/bin/perl

use strict;
use warnings;
use v5.16;
use IPC::ShareLite;
use Data::Dumper;
use Time::HiRes;
use List::MoreUtils qw(uniq);


use constant TIMEOUT  => 1;
use constant NUMSTATS => 10;

my @targets = uniq @ARGV;
die "Usage: $0 [HOST1] [HOST2] [...]" unless @targets;

my (%pids,%shm);

for my $target ( @targets ) {
    warn "Forking for $target" if $ENV{DEBUG};
    my $childpid = fork;
    if (not defined $childpid) {
        # Error
        die "Error forking for target $target: $!";
    }
    elsif ($childpid) {
        # Parent
        $shm{$target} = IPC::ShareLite->new(-key=>$childpid, -create=>1, -destroy=>0);
        $pids{$target} = $childpid;
    }
    else {
        # Child
        $0 = "$0 worker: $target";
        exit pingtarget($target);
    }
}

while (sleep 1) {
    say sprintf '%s %s %s', '#' x 10, scalar(localtime), '#' x 60;
    for my $target ( @targets ) {
        my $pingdata = $shm{$target}->fetch;
        #my @data = map { [split m{/}] } grep {length} split /;/, $pingdata;
        my @data = pstr2data($pingdata);
        #say "$target: " . Dumper(\@data);
        printf "%-40s %s\n", $target, summarize(\@data);
    }
}
exit;

sub summarize {
    my $stats = shift;
    return 'NO STATS YET' unless @$stats;
    my ($sumtime,$sumsuccess) = (0,0);
    for my $s ( @$stats ) {
        $sumsuccess += $s->[1];
        $sumtime += $s->[2];
    }
    my $c = @$stats;
    my $l = $stats->[-1];
    my $sumstr = sprintf 'AVG: %d/%d success % 6.2fms LATEST: seq % 3d %7s  % 6.2fms',
        $sumsuccess,$c, $sumtime/$c*1000,
        $l->[0], $l->[1]?'success':'failure', $l->[2]*1000;
    return $sumstr;
}
sub pstr2data {
    map { [split m{/}] } grep {length} split /;/, $_[0];
}
sub pdata2str {
    my @a = @{shift @_};
    my $max = shift;
    # limit to trailing $max entries if we have more
    @a = @a[(-1*$max)..-1] if $max and @a>$max;
    return join ';', map { join '/', @$_ } @a;
}

sub pingtarget {
    my $target = shift;
    warn "$$ In child for $target" if $ENV{DEBUG};
    my $shm = IPC::ShareLite->new(-key=>$$, -create=>1, -destroy=>0);
    require Net::Ping;
    my $p = Net::Ping->new('icmp');
    $p->hires(1);
    my $i = 0;
    while (1) {
        $i++;
        my ($ret,$dur,$ip) = $p->ping($target,TIMEOUT);
        my $append = sprintf ';%d/%d/%0.3f', $i, $ret, $dur;
        my $pingdata = $shm->fetch;
        $pingdata = $target unless defined $pingdata;
        #$pingdata .= $append;
        my @data = pstr2data($pingdata);
        push @data, [$i, $ret, $dur];
        $pingdata = pdata2str(\@data,NUMSTATS);
        $shm->store( $pingdata );
        sleep 1;
    }
}

