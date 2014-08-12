#!/usr/bin/perl

use Getopt::Long;
use File::Basename;
use File::Path;
use FindBin qw($Bin);
use Cwd;
use Data::Dumper;
use Carp;
use Cwd 'abs_path';
use lib "$Bin/../lib";
require "$Bin/Table.pm";
require "$Bin/makemake.pm";
require "$Bin/makemake/eclipse.pm";
$bset = makemake::set::setNew(['build','alias','link','compile','linklib','gen','dep']);
$lset = makemake::set::setNew(['linklib']);
$eset = makemake::set::setNew(['build','alias','link','compile','gen','dep']);
$aset = makemake::set::setNew(['alias']);
$vset = makemake::set::setNew(['var']);

$OPT{'args'} = join(" ",($0,@ARGV));

sub usage { print("usage: $0 <infiles> [--quiet|--verbose]
    --os=[win,cyg,posic]    : select dest os (default: $defos)
    --pdir=[dir]            : eclipse project dir root
    --makefile=[fn]         : create single Makefile
    --builddir=[dir]        : build directoy
    --projdir=[dir]         : project directoy
    --eclipse-internal=[0|1]: Internal(1) or External build(0,default)
    --dbgtrans              : view path abs2rel transforms
    --dbggraph              : view dependency graph
    --dbgval                : debug value retrival
    --dbgparse              : debug config parse
    --dbggen                : debug ouput generation
    --verbose|-v            : verbose
    --quiet                 : un-verbose
"); exit(1);
}
Getopt::Long::Configure(qw(bundling));
GetOptions(\%OPT,qw{
    quiet|q+
    verbose|v+
    pdir|d=s
    makefile|m=s
    builddir|b=s
    root=s@
    os=s@
    eclipse-internal=i
    dbgtrans
    dbggraph
    dbggen
    dbgparse
    dbgval
} ,@g_more) or usage(\*STDERR);

$def = $ARGV[0];

%g = ();
%n = ();
$g = new makemake::edges(\%g);
$n = new makemake::nodes(\%n);


$OPT{'root'} = ['all'] if(!defined($OPT{'root'}));
$OPT{'root'} = [split(/,/,join(',',@{$OPT{'root'}}))];

$OPT{'builddir'} = 'out' if (!exists($OPT{'builddir'}));
$OPT{'compile'} = "gnuc";
$OPT{'link'} = "gnuld";
$OPT{'ar'} = "gnuar";
$OPT{'builddir'} .= "/" if (length($OPT{'builddir'}) && !($OPT{'builddir'} =~ /[\/\\]$/));
$OPT{'makefile'} = "Makefile.gen.mk" if (!exists($OPT{'makefile'}));
	
#todo: 
# 1. remove equal rules 
# 2. handle same names in different projects
# 3. handle generated filename-generation

# 4. handle genflags in root

# 5. group rules in Makefile under project
# 6. vpath implement

$_phony = makemake::graph::getOrAddRule($g,$n,'.PHONY')->flags(['alias'])->merge({'noresolvealias'=>1});
$_clean = makemake::graph::getOrAddRule($g,$n, 'clean')->flags(['alias']);;
$_opt = $o = makemake::graph::getOrAddNode($g,$n,'_opt')->merge(\%OPT);
makemake::addOptEdge($g,$n,$_clean);
$$_clean{'rules'} = "rm -rf {{\$^}}";
makemake::addToPhony($g,$n,$_clean);

makemake::genConfig::perl_opts($o);
makemake::genConfig::make_opts($o);

#print(Dumper($o));

makemake::readdef($g,$n,$def);
makemake::genmakefile($g,$n,$OPT{'makefile'},$OPT{'root'},{});

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
