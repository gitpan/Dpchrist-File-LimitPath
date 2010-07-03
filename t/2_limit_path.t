# $Id: 2_limit_path.t,v 1.13 2009-12-02 20:27:32 dpchrist Exp $

use Test::More 			tests => 15;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Dpchrist::File::LimitPath	qw( :all );
use File::Basename;


$Data::Dumper::Sortkeys = 1;

$| = 1;

my $c;
my $e;
my $opt = \%Dpchrist::File::LimitPath::opt;
my $p;
my $r;
my $t_tree = "~tmp/t";
my @t_tree = qw(
    ~tmp/t/0
    ~tmp/t/0.ext
    ~tmp/t/10
    ~tmp/t/10.ext
    ~tmp/t/210
    ~tmp/t/210.ext
    ~tmp/t/3210
    ~tmp/t/3210.ext
    ~tmp/t/43/10
    ~tmp/t/43/10.ext
    ~tmp/t/54/210
    ~tmp/t/54/210.ext
    ~tmp/t/65/3210
    ~tmp/t/65/3210.ext
    ~tmp/t/76543210
    ~tmp/t/76543210.ext
    ~tmp/t/876543210
    ~tmp/t/876543210.ext
    ~tmp/t/9876543210
    ~tmp/t/9876543210.ext
    ~tmp/t/zoology-1.23.tar.gz
    ~tmp/t/zoology-4.56.tar.gz
);
#   123456789012345678901234567890
#            1         2         3
my $y;


sub gen_t_tree
{
    if (-e $t_tree) {
	system "rm -rf $t_tree"
	    and confess "ERROR removing tree '$t_tree': $!";
    }
    foreach my $p (@t_tree) {
	my $d = dirname $p;
	system "mkdir -p $d"
	    and confess "ERROR creating directory '$d': $!";
	system "touch $p"
	    and confess "ERROR creating file '$p': $!";
    }
}

sub count_t_tree
{
    my $n = 0;
    
    foreach (@t_tree) { $n++ if -e $_ }

    return $n;
}

sub file_exists
{
    my $retval = 1;

    foreach my $f (@_) {
	if (!-e $f) {
	    warn "expected file '$f' does not exist";
	    $retval = 0;
	}
    }

    return $retval;
}

sub file_missing
{
    my $retval = 1;

    foreach my $f (@_) {
	if (-e $f) {
	    warn "unexpected file '$f' exists";
	    $retval = 0;
	}
    }
    return $retval;
}


$r = eval {
    limit_path;
};
$e = $@;
ok(								#     1
    $e =~ /Required argument LIST missing/,
    'call without arguments should fail'
) or confess join(' ',
    Data::Dumper->Dump([$r, $e], [qw(r e)]),
);

$p = "no/such/path";
$r = eval {
    limit_path $p;
};
$e = $@;
ok(								#     2
    $e =~ /Path .+ does not exist/,
    'call with invalid path should fail',
) or confess join(' ',
    Data::Dumper->Dump( [$r, $e], [qw(r e)]),
);

gen_t_tree();
$opt->{-limit} = 0;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
ok(								#     3
    $e =~ /Option .-limit. out of range/,
    "calling with -limit of 0 should fail"
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

$opt->{-limit} = 32768;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
ok(								#     4
    $e =~ /Option .-limit. out of range/,
    "calling with -limit of 32768 should fail"
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit} = 25;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#     5
    defined $r
    && $r == 1
    && $c == 20
    && file_exists( qw(
       ~tmp/t/zoology-1.~.tar.gz
       ~tmp/t/zoology-4.~.tar.gz ) ),
    "call on '$t_tree' with limit of 25 should rename 2 files",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit} = 24;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#     6
    defined $r
    && $r == 1
    && $c == 20
    && file_exists( qw(
       ~tmp/t/zoology-1~.tar.gz
       ~tmp/t/zoology-4~.tar.gz ) ),
    "call on '$t_tree' with limit of 24 should rename 2 files",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit} = 23;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
ok(								#     7
    $e =~ /Cannot rename .+ destination .+ already exists/,
    "call on '$t_tree' with limit of 23 should fail"
) or confess join(' ',
    Data::Dumper->Dump([$r, $e], [qw(r e)]),
);

gen_t_tree();
$opt->{-limit}  = 23;
$opt->{-delete} =  1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#     8
    defined $r
    && $r == 1
    && $c == 20
    && -e "~tmp/t/zoology-~.tar.gz"
    && !-e "~tmp/t/zoology-4~.tar.gz",
    "call on '$t_tree' with limit of 23 should "
    . "delete 2 files",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 16;
$opt->{-delete} =  1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#     9
    defined $r 
    && $c == 14
    && file_exists( qw(
	~tmp/t/54/2~.ext
	~tmp/t/65/3~.ext
	~tmp/t/7654~.ext
	~tmp/t/8765~.ext
	~tmp/t/98765432~
	~tmp/t/9876~.ext
	~tmp/t/z~.tar.gz )),
    "call on '$t_tree' with limit of 16 should "
    ."rename 7 files and delete 1 file",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 15;
delete $opt->{-delete};
$r = eval {
    limit_path $t_tree;
};
$e = $@;
ok(								#    10
    $e =~ 'Base name of .+ is too short to rename',
    "call on '$t_tree' with limit of 15 should fail"
) or confess join(' ',
    Data::Dumper->Dump([$r, $e], [qw(r e)]),
);

gen_t_tree();
$opt->{-limit}  = 9;
$opt->{-delete} = 1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#    11
    defined $r
    && $c == 2
    && file_exists( qw(
	~tmp/t/0
	~tmp/t/10
	~tmp/t/2~
	~tmp/t/3~
	~tmp/t/7~
	~tmp/t/8~
	~tmp/t/9~ )),
    "call on '$t_tree' with limit of 9 and -delete should "
    . "leave 2 original files and 7 renamed files",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 8;
$opt->{-delete} = 1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#    12
    defined $r
    && $c == 1
    && -e "~tmp/t/0",
    "call on '$t_tree' with limit of 8 and -delete should "
    . "leave 1 original file",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 7;
$opt->{-delete} = 1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#    13
    defined $r
    && $c == 0
    && -d "~tmp/t",
    "call on '$t_tree' with limit of 7 and -delete should "
    . "delete all files but leave parent directory",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 6;
$opt->{-delete} = 1;
$r = eval {
    limit_path $t_tree;
};
$e = $@;
$c = count_t_tree();
ok(								#    14
    defined $r
    && $c == 0
    && -d "~tmp/t",
    "call on '$t_tree' with limit of 6 and -delete should "
    . "delete all files and leave parent directory",
) or confess join(' ',
    Data::Dumper->Dump([$r, $e, $c], [qw(r e c)]),
);

gen_t_tree();
$opt->{-limit}  = 5;
delete $opt->{-delete};
$r = eval {
    limit_path $t_tree;
};
$e = $@;
ok(								#    15
    $e =~ /Option .-limit. out of range/,
    "call on '$t_tree' with limit of 5 should fail"
) or confess join(' ',
    Data::Dumper->Dump([$r, $e], [qw(r e)]),
);

