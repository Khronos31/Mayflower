use strict;
use warnings;

print "hello from perl\n";
system("echo exec_sh_c ok") == 0 or die "system shell";
my $out = `./t.sh`;
chomp $out;
die "shebang `$out`" unless $out =~ /shebang-ok/;
print "$out\n";
print "startProcess rc=0\n";
