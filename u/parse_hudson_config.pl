#!/bin/perl

use strict;
use XML::Parser;
use File::Basename;

use constant SCM_SVN => 'hudson.scm.SubversionSCM_-ModuleLocation';

my ($scm, $remote, $local) = (0, 0, 0);
my ($svn_command, $svn_dir);

undef $/;

my $parser = new XML::Parser ( Handlers => {   # Creates our parser object
        Start   => \&hdl_start,
        End     => \&hdl_end,
        Char    => \&hdl_char,
        Default => \&hdl_def,
        });

$parser->parse(<>);

# The Handlers
sub hdl_start {
    my ($p, $elt, %atts) = @_;

    if ($elt eq SCM_SVN) {
        $scm++;
    } elsif (($scm == 1) and ($elt eq 'remote')) {
        $remote++;
    } elsif (($scm == 1) and ($elt eq 'local')) {
        $local++;
    }
}

sub hdl_end {
    my ($p, $elt) = @_;
    if ($elt eq SCM_SVN) {
        $scm--;
        print <<EOF
if test -d '$svn_dir'/.svn
then
  $svn_command || {
    rm_svn_subdir $svn_dir
    $svn_command
  }
else
  $svn_command
fi
EOF
    } elsif (($scm == 1) and ($elt eq 'remote')) {
        $remote--;
    } elsif (($scm == 1) and ($elt eq 'local')) {
        $local--;
    }
}

sub hdl_char {
    my ($p, $str) = @_;
    if (($scm == 1) and ($remote == 1)) {
        # Extract port
        $svn_command = ($str =~ s/^(svn\+ssh:\/\/[^\/:]+):(\d+)/\1/) ?
          "SVN_SSH='ssh -p $2' " : '';
        $svn_command .= "svn checkout $str";
        $svn_dir = basename($str);
    } elsif (($scm == 1) and ($local == 1)) {
        $svn_command .= " $str";
        $svn_dir = $str;
    }  
}

sub hdl_def { }  # We just throw everything else

