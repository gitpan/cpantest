#!/usr/bin/perl

use Config;
require File::Basename;

my $file = File::Basename::basename($0, '.PL');
$file .= '.com' if $^O eq 'VMS';

open OUT, ">$file" or die "Can't create $file:  $!";
print OUT <<"!GROK!THIS!";
$Config{startperl}
    eval 'exec $Config{perlpath} -S \$0 \${1+"\$@"}'
        if \$running_under_some_shell;
!GROK!THIS!

print OUT <<'!NO!SUBS!';


=head1 NAME

B<cpantest> - Report test results of a package retrieved from CPAN

=head1 DESCRIPTION

B<cpantest> uniformly posts package test results in support of the
cpan-testers project.  See B<http://testers.cpan.org/>
for details.

=head1 USAGE

    cpantest -g grade [ -nc ] [ -auto ] [ -p package ]
             [ email-addresses ]

For MacPerl, save as a droplet, and drop a module archive
or unpacked folder on the droplet.

=head1 OPTIONS

=over 4

=item -g grade

I<grade> indicates the success or failure of the package's builtin
tests, and is one of:

    grade     meaning
    -----     -------
    pass      all tests included with the package passed
    fail      some tests failed
    na        the package does not work on this platform
    unknown   the package did not include tests

=item -p package

I<package> is the name of the package you are testing.  If you don't
supply a value on the command line, you will be prompted for one.

=item -nc

No comment; you will not be prompted to supply a comment about the
package.

=item -auto

Autosubmission (non-interactive); you won't be prompted to supply any
information that you didn't provide on the command line.  Implies I<-nc>.

=item email-addresses

A list of additional email addresses that should be cc:'d in this
report (typically, the package's author).

=back

=head1 AUTHORS

Kurt Starsinic E<lt>F<Kurt.Starsinic@isinet.com>E<gt>, with patches
from the CPAN Testers E<lt>F<cpan-testers@perl.org>E<gt>.

=head1 COPYRIGHT

    Copyright (c) 1999 Kurt Starsinic.
    This program is free software; you may redistribute it
    and/or modify it under the same terms as Perl itself.

=cut

use strict;

use Cwd;
use Mail::Send;
use Config;
use Getopt::Long;


use vars qw($VERSION);
$VERSION = "0.93";

use vars qw(%Grades $CC $CPAN_testers $Report);
%Grades = (     # Legal grades:
    'pass'      => "all tests pass",
    'fail'      => "some tests fail",
    'na'        => "package will not work on this platform",
    'unknown'   => "package did not include tests",
);
$CPAN_testers   = 'cpan-testers@perl.org';
$Report         = $ENV{CPANTEST} ||
                ($ENV{TMPDIR} ? "$ENV{TMPDIR}/CPANTEST.RPT" : "CPANTEST.RPT");


### Process command line:
use vars qw($Grade $Package $No_comment $Automatic $Comment_text $MacApp
$MacMPW);

$MacMPW = $^O eq 'MacOS' && $MacPerl::Version =~ /MPW/;
$MacApp = $^O eq 'MacOS' && $MacPerl::Version =~ /Application/;

if ($MacApp) {
    DoMacOptions();
} else {
    GetOptions(
        'g=s',  \$Grade,
        'p=s',  \$Package,
        'nc',   \$No_comment,
        'auto', \$Automatic,
        't=s',  \$Comment_text,
    ) or usage();

    $CC = join ' ', @ARGV;
    $No_comment = 1 if ($Automatic && !$Comment_text);
}

usage("-g <grade> is required")    unless defined $Grade;
usage("grade `$Grade' is invalid") unless defined $Grades{$Grade};
usage("-p is required with -auto") if $Automatic and !$Package;

my $comment_marker = $No_comment ? '' :
  sprintf(qq{-- \n%s\n\n},
    $Comment_text ? $Comment_text : '[ insert comments here ]');


### Compose report:
    open REPORT, ">$Report" or die "cannot open $Report:  $!";
        print REPORT <<"EOF";
This distribution has been tested as part of the cpan-testers
effort to test as many new uploads to CPAN as possible.  See
http://testers.cpan.org/

Please cc any replies to cpan-testers\@perl.org to keep other
test volunteers informed and to prevent any duplicate effort.

$comment_marker
--

EOF
    print REPORT Config::myconfig();
    close REPORT;

unless ($No_comment || $Comment_text) {
    my $editor  = $ENV{VISUAL} || $ENV{EDITOR} || $ENV{EDIT}
                || ($^O eq 'VMS'     and "edit/tpu")
                || ($^O eq 'MSWin32' and "notepad")
                || ($^O eq 'MacOS' and 'ttxt')
                || 'vi';

    $editor = prompt('Editor', $editor) unless $MacApp;

    if ($^O eq 'MacOS') {
        use vars '%Application';
        foreach my $mod (qw(
            Mac::MoreFiles
            Mac::AppleEvents::Simple
            Mac::AppleEvents
        )) {
            eval qq(require $mod) or die "die: Can't load $mod.\n";
            eval qq($mod->import());
            }

        my $app = $Application{$editor};
        die "Application with ID '$editor' not found.\n" if !$app;

        my $obj = 'obj {want:type(cobj), from:null(), ' .
          'form:enum(name), seld:TEXT(@)}';
        my $evt = do_event(qw/aevt odoc MACS/,
            "'----': $obj, usin: $obj", $Report, $app);

        if (my $err = AEGetParamDesc($evt->{REP}, 'errn')) {
            die "AppleEvent error: ${\AEPrint($err)}.\n";
        }

        prompt('Done?', 'Yes') if $MacMPW;
        MacPerl::Answer('Done?') if $MacApp;

    } else {
        die "The editor `$editor' could not be run"
            if system "$editor $Report";
    }
    $CC ||= ask_cc() unless $MacApp;
}


my ($subject, $msg);

if (!$Package) {
    $Package =  cwd();
    $Package =~ s:.*/::;
    $Package = prompt('Package', $Package);
}

# Are there _any_ useful limitations we can put on $Package?  This has
# proven to be too restrictive:
#usage("`$Package' should end with a dash and version number only")
#    unless $Package =~ /-[\.0-9]+$/;

$subject    = uc($Grade) . " $Package $Config{archname} $Config{osvers}";

if (!$Automatic) {
    $subject    = prompt('Subject', $subject);

    print "\n";
    print "Subject:  $subject\n";
    print "To:  $CPAN_testers\n";
    print "Cc:  $CC\n" if defined $CC;

    if (prompt('Send/Ignore', 'Ignore') !~ /^[Ss]/) {
        print "Ignoring message.\n";
        exit 1;
    }
}

$msg = new Mail::Send Subject => $subject, To => $CPAN_testers;

if (defined $CC) {
    $CC =~ s/\s+/, /g;
    $msg->cc($CC);
}

$msg->set('X-reported-via', "cpan-test version $VERSION");

my $fh = $msg->open;
    open REP, $Report;
        while (<REP>) { print $fh $_ }
    close REP;
$fh->close;

if($ENV{CPANTEST_LOG}) {
    open(LOG,">>$ENV{CPANTEST_LOG}") or
         die "Unable to open $ENV{CPANTEST_LOG}";
    my $time = localtime;
    print LOG "$subject $time\n";
    close(LOG);
}

### End of main program; subroutines follow


sub ask_cc
{
    my $cc = prompt('CC', 'none');

    return ($cc eq 'none') ? undef : expand_author($cc);
}


# Given an author identifier (either a CPAN authorname or a proper
# email address), return a proper email address.
sub expand_author
{
    my ($author)    = @_;

    if ($author =~ /^[-A-Z]+$/) {   # Smells like a CPAN authorname
        eval { require CPAN } or return undef;

        my $cpan_author = CPAN::Shell->expand("Author", $author);

        return eval { $cpan_author->email };
    }
    elsif ($author =~ /^\S+@[a-zA-Z0-9\.-]+$/) {
        return $author;
    }

    return undef;
}


# Prompt for a new value for $label, given $default; return the user's
# selection.
sub prompt
{
    my ($label, $default)   = @_;

    printf "$label%s", ($MacMPW ? ":\n$default" : " [$default]: ");
    my $input = scalar <STDIN>;
    chomp $input;

    return (length $input) ? $input : $default;
}


sub usage
{
    my ($message)   = @_;

    print "Error:  $message\n" if defined $message;
    print "Usage:\n";
    print "  cpantest -g grade [ -nc ] [ -auto ] [ -p package ]\n";
    print "           [ email-addresses ]\n";
    print "  -g grade  Indicates the status of the tested package.\n";
    print "            Possible values for grade are:\n";

    foreach (keys %Grades) {
        printf "              %-10s  %s\n", $_, $Grades{$_};
    }

    print "  -p        Specify the name of the distribution tested.\n";
    print "  -nc       No comment; you will not be prompted to comment on\n";
    print "            the package.\n";
    print "  -auto     Autosubmission (non-interactive); implies -nc.\n";

    exit 1;
}


sub DoMacOptions {
    require File::Basename;

    if ($ARGV[0]) {
        ($Package = File::Basename::basename($ARGV[0])) =~ s/\.t(?:ar\.)?gz$//;
    }

    $Package    = MacPerl::Ask('Package Name?', $Package);
    $Grade      = MacPerl::Pick('What Grade?', qw(pass fail unknown na));
    $No_comment = MacPerl::Answer('Comment on submission?', qw(No Yes));
    $CC         = MacPerl::Ask('Cc: to address?');
    $Automatic  = 1;
}

!NO!SUBS!

close OUT or die "Can't close $file:  $!";
chmod 0755, $file or die "Can't reset permissions for $file:  $!\n";

exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';

