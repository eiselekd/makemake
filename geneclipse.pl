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
require "$Bin/geneclipse_pkg.pl";
require "$Bin/geneclipse_graph.pl";
require "$Bin/geneclipse_util.pl";
$bset = set::setNew(['build','alias','link','compile','linklib','gen','dep']);
$vset = set::setNew(['var']);

$OPT{'args'} = join(" ",($0,@ARGV));

sub usage { print("usage: $0 <infiles> [--quite|--verbose]
    --os=[win,cyg,posic]    : select dest os (default: $defos)
    --pdir=[dir]            : eclipse project dir root
    --makefile=[fn]         : create single Makefile
    --builddir=[fn]         : build directoy
    --dbgtrans              : view path abs2rel transforms
    --dbggraph              : view dependency graph
    --dbgval                : debug value retrival
    --dbgparse              : debug config parse
    --dbggen                : debug ouput generation
"); exit(1);
}
Getopt::Long::Configure(qw(bundling));
GetOptions(\%OPT,qw{
    quite|q+
    verbose|v+
    pdir|d=s
    makefile|m=s
    os=s@
    dbgtrans
    dbggraph
    dbggen
    dbgparse
    dbgval
} ,@g_more) or usage(\*STDERR);

$def = $ARGV[0];

%g = ();
%n = ();

$OPT{'builddir'} = 'out'; #$OPT{'builddir'} || 'out';
$OPT{'compile'} = "gnuc";
$OPT{'link'} = "gnuld";
$OPT{'ar'} = "gnuar";

%tools = 
  (
   'gnuc'=> 
   new tool_compile(\%g,\%n,'gnuc',
	  {
	   'cc' => 'gcc',
	   'txt' => '{{cc}} {{["wrap"=>"-I^ "]get-set:srcs.cinc}} {{["wrap"=>"\$(^) "]get-set:srcs.cflags}}  {{["wrap"=>"^ "]get:srcs.relfname}} -o {{get:obj.relfname}} '
	  }),
   'gnuld'=> 
   new tool_link(\%g,\%n,'gnuld',
	  {
	   'ld' => 'ld',
	   'txt' => '{{ld}} {{["wrap"=>"^ "]get-set:srcs.relfname}} -o {{get:obj.relfname}} '
	  }),
   'gnuar'=> 
   new tool_link(\%g,\%n,'gnuar',
	  {
	   'ar' => 'ar',
	   'txt' => '{{ar}} cr {{get:obj.relfname}} {{["wrap"=>"^ "]get-set:srcs.relfname}} '
	  })
);

$o = getOrAddNode(\%g,\%n,'_opt')->merge(\%OPT);

genConfig::perl_opts($o);

#print(Dumper($o));

readdef(\%g,\%n,$def);
genmakefile(\%g,\%n,'all');

#print("varuse:\n");
#deepPrint(\%g,\%n,'all');

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
