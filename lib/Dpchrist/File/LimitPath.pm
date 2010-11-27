#######################################################################
# $Id: LimitPath.pm,v 1.32 2010-11-27 03:37:58 dpchrist Exp $
#######################################################################
# package:
#----------------------------------------------------------------------

package Dpchrist::File::LimitPath;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
    limit_path	    
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = sprintf "%d.%03d", q$Revision: 1.32 $=~/: (\d+)\.(\d+)/;

#######################################################################
# uses:
#----------------------------------------------------------------------

use constant			DEBUG => 0;

use Carp;
use Data::Dumper;
use Dpchrist::Debug		qw( :all );
use File::Basename;
use File::Copy;
use File::Find;

#######################################################################
# package variables:
#----------------------------------------------------------------------

our $limit_high = 32767;	# range limits on -limit option
our $limit_low;			# low limit is longest LIST item length

our %long_paths;		# key is path
				# value is length

our %opt = (			# options
    -limit	=> 220,
);

#######################################################################
# private subroutines:
#----------------------------------------------------------------------

sub _nuke($)
{
    ddump 'entry', [\@_], [qw(*_)] if DEBUG;

    my $retval;

    my $f = shift;

    if (-d $f) {
	my $msg = "rmdir\t'$f'\n";
	print $msg unless $opt{-quiet};
	dprint $msg if DEBUG;
	$retval = rmdir $f
	    or confess "Failed to remove directory '$f': $!";
    }
    else {
	my $msg = "unlink\t'$f'\n";
	print $msg unless $opt{-quiet};
	dprint $msg if DEBUG;
	$retval = unlink $f
	    or confess "Failed to unlink file 'f': $!";
    }

    ddump 'returning', [$retval], [qw(retval)] if DEBUG;
    return $retval;
}

#----------------------------------------------------------------------

sub _wanted
{
    ddump 'entry', [\@_], [qw(*_)] if DEBUG;

    my $f = $File::Find::name;

    my $l = length($f);

    ddump [$f, $l], [qw(f l)] if DEBUG;

    if ($opt{-limit} < $l) {
	$long_paths{$f} = $l;
	ddump [\%long_paths], [qw(long_paths)] if DEBUG;
    }

    dprint 'returning' if DEBUG;
    return;
}

#######################################################################

=head1 NAME

Dpchrist::File::LimitPath - limit path lengths


=head1 DESCRIPTION

This documentation describes module revision $Revision: 1.32 $.


This is alpha test level software
and may change or disappear at any time.


=head2 SUBROUTINES

=cut

#######################################################################

=head3 limit_path

    limit_path LIST

Checks path length of each item in LIST
and shortens file names to keep path length
less than or equal to a prescribed limit (default 220).
If a list item is a directory,
processes contained files recursively.
Returns true (1).

Prints the names of shortened files.
Use the "-quiet" option to suppress.


Options may be set via %Dpchrist::File::LimitPath::opt:

=over

=item -delete => [0|1]

Delete files that are too long but can't be shortened.
Delete files that, if renamed, would collide with other files
(previously existing or another renamed file).

=item -dry_run => [0|1]

Check files, but don't rename any.

=item -limit => LIMIT

Maximum path length in characters.
Must be between the longest LIST item length and 32767 (inclusive).

=item -quiet => [0|1]

Only output error messages.

=back


Calls Carp::confess() on errors, including:

=over

=item * LIST is empty.

=item * -limit option is less than longest list item length.

=item * Shortening file name would reduce file name
to less than 1 character plus tilde plus dot plus extension.
Use the "-delete" option to delete such files instead.

=item * Shortening file name would result in a file name collision.
Use the "-delete" option to delete such files instead.

=back

=cut

#----------------------------------------------------------------------

sub limit_path
{
    ddump 'entry', [\@_], [qw(*_)] if DEBUG;


    ### process arguments:

    confess 'Required argument LIST missing' unless 0 < @_;

    $limit_low = 1;
    foreach (@_) {
	confess "Path '$_' does not exist" unless -e $_;
	my $l = length($_);
	$limit_low = $l if $limit_low < $l;
    }

    ### set options:

    confess join(' ',
	"Option '-limit' out of range $limit_low to $limit_high",
	Data::Dumper->Dump([%opt], [qw(*opt)]),
    ) unless $limit_low <= $opt{-limit}
	  && $opt{-limit} <= $limit_high;


    ### find files with long paths:

    %long_paths = ();

    find \&_wanted, @_;
    ddump [\%long_paths], [qw(*long_paths)] if DEBUG;


    ### adjust names of files with long paths:

    foreach my $f (sort {length $b <=> length $a} keys %long_paths) {

	unless (-e $f) {			# sanity check
	    my $msg = "file '$f' has disappeared";
	    warn $msg unless $opt{-quiet};
	    dprint $msg if DEBUG;
	    next;
	}

	my $l = $long_paths{$f};

	my $dirname  = dirname($f);

	my $basename = basename($f);

	my @a = split /\./, $basename;
	
	ddump [   $f, $l, $dirname, $basename, \@a],
    	      [qw( f   l   dirname   basename   *a)] if DEBUG;

	my $base;
	my $ext;

	if (scalar @a == 0) {
	    $base = $basename;
	    $ext = "";
	}
	elsif (scalar @a == 1) {
	    $base = $a[0];
	    $ext = $a[1];
	}
	else {
	    $ext = pop @a;
	    $ext = join('.', pop @a, $ext)
		    if $a[-1] eq 'tar' && $ext eq 'gz';
	    $base = join('.', @a);
	}

	### number of characters we need to keep in base:

	my $n = length($base)
		- ($l - $opt{-limit})	# amount over limit
		- 1;			# tilde

	ddump [$base, $ext, $n],
	    [qw(base   ext   n)] if DEBUG;

	if ($n < 1) {
	    if ($opt{-delete}) {
	    	_nuke $f unless $opt{-dry_run};
	    }
	    else {
		confess "Base name of '$f' is too short to rename";
	    }
	}
	else {
	    my $b = substr $base, 0, $n;

	    my $new = $dirname . '/' . $b . '~';
	    $new .= '.' . $ext if $ext;

	    ddump [$b, $new], [qw(b new)] if DEBUG;

	    if (-e $new) {
		if ($opt{-delete}) {
	    	    _nuke $f unless $opt{-dry_run};
		}
		else {
		    confess "Cannot rename '$f': " .
		    	    "destination '$new' already exists";
		}
	    }
	    else {
		print "move\t'$new'\n"
		    unless $opt{-quiet};
		move($f, $new)
		    or confess "failed moving file '$f' to '$new': $!";
	    }
	}
    }


    ### done:

    my $retval = 1;

    ddump 'returning', [$retval], [qw(retval)] if DEBUG;
    return $retval;
}

#######################################################################
# end of module:
#----------------------------------------------------------------------

1;

__END__

#######################################################################
# remaining POD:
#----------------------------------------------------------------------

=head2 EXPORT

None by default.

All of the subroutines may be imported by using the ':all' tag:

    use Dpchrist::File::LimitPath    qw( :all );

See 'perldoc Export' for everything in between.

		    
=head1 INSTALLATION

Old school:

    $ perl Makefile.PL
    $ make
    $ make test
    $ make install

Minimal:

    $ cpan Dpchrist::File::LimitPath

Complete:

    $ cpan Bundle::Dpchrist

The following warning may be safely ignored:

    Can't locate Dpchrist/Module/MakefilePL.pm in @INC (@INC contains: /
    etc/perl /usr/local/lib/perl/5.10.0 /usr/local/share/perl/5.10.0 /us
    r/lib/perl5 /usr/share/perl5 /usr/lib/perl/5.10 /usr/share/perl/5.10
    /usr/local/lib/site_perl .) at Makefile.PL line 22.


=head2 PREREQUISITES

See Makefile.PL in the source distribution root directory.


=head1 SEE ALSO

    limitpath(1)


=head1 AUTHOR

David Paul Christensen dpchrist@holgerdanske.com


=head1 COPYRIGHT AND LICENSE

Copyright 2010 by David Paul Chirstensen dpchrist@holgerdanske.com

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,
USA.

=cut

#######################################################################
