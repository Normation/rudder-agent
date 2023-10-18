#!/usr/bin/perl
use warnings;
use strict;

# jenkins hash, or one at a time : /* https://en.wikipedia.org/wiki/Jenkins_hash_function#one-at-a-time */
sub hash {
  my $str = shift;
  my $h = 0;
  use integer;
  for(my $i=0;$i<length($str);$i++) {
    my $c = substr($str, $i, 1);
    $h += ord($c);
    $h += ($h << 10) ;
    $h &= 0xFFFFFFFF;
    $h ^= ($h >> 6);
    $h &= 0xFFFFFFFF;
  }

  $h += ($h << 3);
  $h &= 0xFFFFFFFF;
  $h ^= ($h >> 11);
  $h &= 0xFFFFFFFF;
  $h += ($h << 15);
  $h &= 0xFFFFFFFF;

  return $h
}

# open file created by cf-execd
open(my $file, "</var/rudder/tmp/cf-execd.data") or exit();
# data to hash for splaytime
my $str = <$file>;
chomp $str;
# cf-execd startup time
my $startup_time = <$file>;
# configured splay
my $splay = <$file>;
# agent run period in minute
my $run_period = <$file>;

# splay as calculated by cf-execd
my $hash = hash($str);
my $splay_s = $splay * 60 * $hash / 0xFFFFFFFF;

# cf-execd sleeps per 1mn until it reaches the scheduled period
$run_period *= 60;
my $time = time();
my $last_wake_up = $time - ($time % $run_period) + ($startup_time % 60);
my $run_time = $last_wake_up + $splay_s;
if ($run_time < $time) {
  # the agent has already run, add one period
  $run_time += $period
}

# we could subtract $time directly in the formulas above but it would be harder to understand
my $wait = $run_time - $time;
print("$wait\n");

