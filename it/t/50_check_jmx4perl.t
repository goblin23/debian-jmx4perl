# -*- mode: cperl -*-
#!/usr/bin/perl

use FindBin;
use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;
use JMX::Jmx4Perl::Alias;

my $jmx = It->new->jmx4perl;
my ($ret,$content);

0 && do {
($ret,$content) = &exec_check_perl4jmx();
is($ret,3,"No args --> UNKNOWN");

# ====================================================
# Basic checks
my %s = (
         ":10000000000" => [ 0, "OK" ],
         "1:" => [ 0, "OK" ],
         ":1" => [ 2, "CRITICAL" ],
         "5:6" => [ 2, "CRITICAL" ]
);
for my $k (keys %s) {
    ($ret,$content) = &exec_check_perl4jmx("--mbean java.lang:type=Memory --attribute HeapMemoryUsage",
                                           "--path used -c $k");
    is($ret,$s{$k}->[0],"Memory -c $k : $ret");
    ok($content =~ /^$s{$k}->[1]/,"Memory -c $k : " . $s{$k}->[1]);
}

# ====================================================
# Alias attribute checks
for my $k (keys %s) {
    ($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED -c $k");
    is($ret,$s{$k}->[0],"MEMORY_HEAP_USED -c $k : $ret");
    ok($content =~ /^$s{$k}->[1]/,"MEMORY_HEAP_USED $k : " . $s{$k}->[1]);
}

# ====================================================
# Relative value checks
%s = (
      ":90" => [ 0, "OK" ],
      "1:" => [ 0, "OK" ],
      ":1" => [ 1, "WARNING" ],
      "56:57" => [ 1, "WARNING" ]      
);

for my $base (qw(MEMORY_HEAP_MAX java.lang:type=Memory/HeapMemoryUsage/max 100000000)) {
    for my $k (keys %s) {
        ($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED --base $base -w $k");
        is($ret,$s{$k}->[0],"Relative to $base -w $k : $ret");
        ok($content =~ /^$s{$k}->[1]/,"Relative to $base $k : " . $s{$k}->[1]);
    }
}

# ====================================================
# Incremental value checks

$jmx->execute(JMX4PERL_HISTORY_RESET);

($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED --delta -c 10 --name mem");
is($ret,0,"Initial history fetch returns OK");
ok($content =~ /mem=(\d+)/ && $1 eq "0","Initial history fetch returns 0 Threads");

my $mem = $jmx->get_attribute(MEMORY_HEAP_USED);
my $c = 0.05 * $mem;
($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED --delta -c -$c:$c --name mem");
is($ret,0,"Initial history fetch returns OK for -c $c");
ok($content =~ /mem=(\d+)/ && $1 ne "0","History fetch return non null Mem-Delta ($1)");

$jmx->execute(JMX4PERL_HISTORY_RESET);

};


# ====================================================
# Operation return value check

$jmx->execute("jmx4perl.it:type=operation","reset");

($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Initial operation");
ok($content =~ /counter=(\d+)/ && $1 eq "0","Initial operation returns 0");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Second operation");
ok($content =~ /counter=(\d+)/ && $1 eq "1","Second operation returns 1");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,2,"Third operation");
ok($content =~ /counter=(\d+)/ && $1 eq "2","Third operation returns 2");

print "R: $ret, C:\n$content\n";

sub exec_check_perl4jmx {
    my @args;
    for (@_) {
        push @args,split;
    }
    my ($url,$user,$password,$product) = @ENV{"JMX4PERL_GATEWAY","JMX4PERL_USER",
                                                "JMX4PERL_PASSWORD","JMX4PERL_PRODUCT"};
    push @args,("--user",$user,"--password",$password) if $user;
    push @args,("--product",$product) if $product;
    push @args,("--url",$url);

   
    my $cmd = "$FindBin::Bin/../../scripts/check_jmx4perl "
          .join(" ",map { '"' . $_ . '"' } @args); 
    open (F,"$cmd 2>&1 |") 
      || die "Cannot open check_jmx4perl: $!";
    my $content = join "",<F>;
    close F;
    
    if ($? == -1) {
        die "check_jmx4perl: failed to execute: $!\n";
    }
    elsif ($? & 127) {
        die "check_jmx4perl child died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    return ($? >> 8,$content);
}