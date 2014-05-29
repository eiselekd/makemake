use Getopt::Long;
use File::Basename;
use File::Path;
use FindBin qw($Bin);
use Cwd;
use Data::Dumper;
use Cwd 'abs_path';
use lib "$Bin/../lib";
require "$Bin/geneclipse_pkg.pl";

$defos = "posix";
$defos = "win" if ($^O eq 'MSWin32');

$id                         = qr'[a-zA-Z\._]+';
$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;
$RE_balanced_smothbrackets  = qr'(?:[\(]((?:(?>[^\(\)]+)|(??{$RE_balanced_smothbrackets}))*)[\)])'s;
$RE_balanced_brackets       = qr'(?:[\{]((?:(?>[^\{\}]+)|(??{$RE_balanced_brackets}))*)[\}])'s;

%OPT = ();

sub cmpNode {
    my ($from,$to) = @_;
    return $from eq $to;
}

sub printIndent {
    my ($indent) = @_;
    for (my $i = 0; $i < $indent; $i++) {
	print ("  ");
    }
}

# get all nodes $from,$to edges that have eather an
# action <$step> set. $step can be a single action or an array of actions
sub getNode {
    my ($g,$from,$step) = @_;
    my @m = map { [$_,$$g{$from}{$_}] }
        grep { my $to = $_; !defined($step) || scalar( grep { $_ } map { exists($$g{$from}{$to}{$_}) } ((ref $step eq 'ARRAY') ? @$step : $step)) } keys(%{$$g{$from}});
    return @m;
}

# get all edges of graph <g>
sub getAllEdges {
    my ($g) = @_; my @r = ();
    foreach my $from (keys %$g) {
        foreach my $to (keys %{$$g{$from}}) {
	    push(@r, [$from, $to, $$g{$from}{$to}]); 
	}
    }
    return @r;
}
sub getAllEdges_to   { my ($g,$to) = @_; return grep { cmpNode($_[0],$to) } getAllEdges($g); }
sub getAllEdges_from { my ($g,$to) = @_; return grep { cmpNode($_[1],$to) } getAllEdges($g); }


# deep traverse, return all edges starting from node $e. For each edge call $f
# g: graph, n: nodes
sub deepEdge_f {
    my ($g,$n,$e,$f,$a) = @_; my @r = (); my @p = ([$e,0]); my %h = ();
    while(scalar(@p)) {
	my ($from,$deep) = @{shift(@p)};
	if (!exists($h{$from})) {
	    map { &$f($g,$n,$a,$from,$_,$deep) } keys %{$$g{$from}};
	    $h{$from}=1;
	    push(@p, map { [$_, $deep+1] } keys %{$$g{$from}});
	}
    }
}
sub deepEdge {
    my ($g,$n,$e) = @_; my @r = ();
    deepEdge_f($g,$n,$e,sub { my ($g,$n,$r,$from,$to,$deep) = @_; push(@$r, [$from,$to]); return 0;}, \@r);
    return @r;
}

sub deepEdge_print {
    my ($g,$n,$e) = @_;
    deepEdge_f($g,$n,$e,sub { 
	my ($g,$n,$r,$from,$to,$deep) = @_;  
	printIndent($deep); 
	my $cmd = "";
	$cmd = $$g{$from}{$to}{'gen'}{'cmd'} if (exists($$g{$from}{$to}{'gen'}{'cmd'}));
	print(" + '$from=>$to' : $cmd\n"); return 0;}, \@r);
}

# deep traverse, return all nodes starting from node $e. For each node call $f
# g: graph, n: nodes
sub deepSearch_f {
    my ($g,$n,$e,$f,$a) = @_; my @r = (); my @p = ([$e,0]); my %h = ();
    while(scalar(@p)) {
	my ($from,$deep) = @{shift(@p)};
	if (!exists($h{$from})) {
	    #print (":$from\n");
	    last if (&$f($g,$n,$a,$from,$deep));
	    $h{$from}=1;
	    push(@p, map { [$_, $deep+1] } keys %{$$g{$from}});
	}
    }
}
sub deepSearch {
    my ($g,$n,$e) = @_; my @r = ();
    deepSearch_f($g,$n,$e, sub { my ($g,$n,$r,$from,$deep) = @_; push(@$r,[$from]); return 0;}, \@r); 
    return @r;
}
sub isLeaf { my ($g,$from) = @_; scalar(keys($$g{$from})) == 0; }

sub deepPrint {
    my ($g,$n,$e) = @_; 
    deepSearch_f($g,$n,$e, sub { my ($g,$n,$r,$from,$deep) = @_; printIndent($deep); print(" + '$from'\n"); return 0;}, \@r); 
}

sub mergeHashRec {
  my ($a,$b,$k) = @_;
  my @k = keys %$b;  
  @k = @$k if (defined($k));
  foreach my $k (@k) {
    if (!exists($$a{$k})) {
      $$a{$k} = $$b{$k};
    } else {
      if ((ref $$b{$k} eq ref $$a{$k}) && 
	  (ref $$b{$k} eq ref {})) {
	mergeHashRec($$a{$k}, $$b{$k});
      } elsif ((ref $$b{$k} eq ref $$a{$k}) && 
	       (ref $$b{$k} eq ref [])) {
	push (@{$$a{$k}},@{$$b{$k}});
      } elsif ((ref $$a{$k} eq ref [])) {
	push (@{$$a{$k}},$$b{$k});
      } else {
	print("Cannot merge $k\n");
      }
    }
  }
}

sub readdef {
    my ($fn) = @_; 
    my $dir = $OPT{'dir'};
    $def = geneclipse::readfile($fn);
    while($def =~ /($id)\s*$RE_balanced_brackets?\s*:\s*$RE_balanced_squarebrackets/g) {
        
	my %g = ();      # graph edges 
	my %nodes = ();  # nodes
	my $f = template::trim($1);
	my $aproj = eval("{".template::trim($2)."}");
	my @cinc = @{$$aproj{CINC}} or ();
	my $genv = new genenv({'cflags'=>[CFLAGS],'ldflags'=>[]});
	$$genv{'pdir'}="$dir/$f";
	$$genv{'pdirbuild'}="$dir/$f/obj";
	my @makeinc = ();
	my @cleans = ();
	my $groot = "";
	
	if ($f eq 'OPTIONS') {
	  next;
	}

	foreach my $k (keys %{$aproj}) {
	    $$genv{$k} = $$aproj{$k};
	}
	
	my $b = template::trim($3);
	if ($f =~ /(.+\.a)$/ && length($b)) {
	    my $n = $1;
	    $b =~ s/\\\n//g;
	    my @b = split("[\\n]+",$b);
	    #print ("$n:\n");
	    my $p = new project({'name'=>$n,'pdir'=>"$dir/$n"});
	    
	    mergeHashRec($p,$aproj);

	    my $nar = $p->pdir_build("${n}");
	    $groot = $nar;
	    
	    my $i = 0;
	    for ($i = 0; $i < scalar(@b); $i++) {
		# parse all files, a bracket can come at the end of the line
		my $b = $b[$i];
		$b = template::trim($b);
		next if (!length($b));
		my $a = {};
		# detect bracket at end of line : 
		# .. 
		# file1.c  : { attr1 => val }
		# ..
		if ($b =~ /:\s*$RE_balanced_brackets\s*$/g) {
		    $b = $`;
		    $a = eval("{$1}");
		    warn $@ if $@;
		} elsif ($b =~ /:\s*\{$/) {
		    # detect multiline bracket at end of line : 
		    # .. 
		    # file1.c { 
		    #   attr1 => val 
		    # }
		    # ..
		    $b = $`;
		    my $c = "{"; $i++;
		    while ($i < scalar(@b)) {
			$c = $c."\n".$b[$i];
			#print "Test '$c'\n";
			if ($c =~ /^\s*$RE_balanced_brackets/g ) {
			    $b[$i] = $'; $i--; #'
			    $a = $1;
			    #print "Eval $a\n";
			    $a = eval("{$a}");
			    warn $@ if $@;
			    last;
			}
			$i++;
		    }
		    #print("Found attr: ".Dumper($a));
		}
		$b = $p->doSub($b);
		$b = template::trim($b);
		# at this point we have:
		# $b == file
		# $a == attributes
		my $o = undef;
		if ($b =~ /^(.*)\.c$/ || $b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/) {
		    $o = $p->pdir_build(basename(${1}).".o");
		    @{$g{$nar}{$o}}{qw(link)} = ({});
		    @{$g{$o}{$b}}{qw(compile dep)} = ({},[]);
		    #print(Dumper($a));
		    mergeHashRec($g{$o}{$b}{'compile'},$a,['cflags','ldflags']);
		    #print(Dumper($g{$o}{$b}{'compile'}));
		    my $d = new files({'file'=>$b});
		    $p->add($d);
		} elsif ($b =~ /^(.*)\.a$/) {
		    @{$g{$nar}{$b}}{qw(linklib)} = ({});
		}
		#mergeHashRec($g{$b}{$b},$a);
		
		
		
		#if ($g{$o}{$b}) {
		  #$g{$o}{$b}
		#}
		
		if (exists($$a{'gen'})) {
		  my $f = $$a{'gen'}{'from'};
		  $g{$b}{$f}{'gen'} = {};
		  #print("#########\n");
		  mergeHashRec($g{$b}{$f}{'gen'},$$a{'gen'});
		}
		
		#if (defined($g{$from}{$to}{'dep'})) {
		#  push(@dep,@{$g{$from}{$to}{'dep'}}) ;
		#}

	    }
	    
	    $p->saveTo();
	    my $c = new cproject({'name'=>$n,'pdir'=>"$dir/$n"});
	    $c->saveTo();
	    
	    #print ("Dep of $n:\n");
	    my @h = getNode(\%g,$n,'link');
	    #print ("=".Dumper(\@h));
	    my $m = new makefile({'_up'=>$genv,'name'=>$n,'pdir'=>"$dir/$n"}); # ,'dos'=>1
	    
	    foreach my $f (@makeinc) {
	      my $rf = $f;
	      $m->addPart(new textsnipppet({'_up'=>$m},"{{os.make.inc}} {{file${rf}elif}}\n"));
	    }
	    
	    my $cinc = "CFLAGS= -g  ".join(" ",map { "-I {{file".$_."elif}} " } @cinc)."\n";
	    #print("cinc:$cinc\n");
	    $m->addPart(new textsnipppet({'_up'=>$m},$cinc));
	    
	    my @e = grep { !isLeaf(\%g,$$_[0]) } deepSearch(\%g, \%nodes, $nar);
	    
	    foreach my $e (@e) {
		my ($from,$a0,$a1) = @$e; my @a = (); my @to = ();
		my @dep = (); my @to = (); my @gen = (); 
		my %link = (), $link_opt = (new optsnippet({})), %compile = ();
		foreach my $to (keys(%{$g{$from}})) {
		  #print("to $to\n");
		  push(@to,$to);
		  if (exists($g{$from}{$to}{'link'})) {
		    $link{$to} = new optsnippet({}) if (!defined($link{$to}));
		    mergeHashRec($link_opt,$g{$from}{$to}{'link'}); # union linkoptions
		  }
		  if (exists($g{$from}{$to}{'compile'})) {
		    $compile{$to} = new optsnippet({}) if (!defined($compile{$to}));
		    mergeHashRec($compile{$to},$g{$from}{$to}{'compile'});
		    push(@cleans,$from);
		  }
		  if (defined($g{$from}{$to}{'dep'})) {
		    push(@dep,@{$g{$from}{$to}{'dep'}}) ;
		  }
		  if (exists($g{$from}{$to}{'gen'}{'cmd'})) {
		    push(@gen,$g{$from}{$to}{'gen'}{'cmd'});
		    push(@cleans,$from);
		  }
		}
		print ("$from(=>".join(",",@to).") : ".join(" ", (keys(%link),keys(%compile), @dep) )."\n");
		
		my   @rules = ();
		push(@rules,map { new textsnipppet({'_up'=>$compile{$_}},"\tgcc {{['gather'=>1,'join'=>' ','wrap'=>'\$(^)']cflags}} -c -o \$@ {{\$<}}\n") } keys(%compile)); # one cmd per .o
		push(@rules,map { new textsnipppet({'_up'=>   $link_opt},"\tar cr \$@ {{\$^}}\n") } [keys(%link)]) if (scalar(keys(%link))); # only one link
		push(@rules,map { new textsnipppet({},"\t$_") } @gen) if (scalar(@gen));
		
		my $r = new makefile_rule({'rules'=>[@rules],'_target'=>"${from}",'_rulesdep'=>[keys(%link),keys(%compile),@dep]});
		$m->addPart($r);
	    }
	    
	    #$m->addRule($brule);
	    push(@cleans,"${nar}");
	    
	    $m->addPart(new makefile_rule({'rules'=>"",'_rulesdep'=>["${nar}"],                        '_target'=>'all'}));
	    $m->addPart(new makefile_rule({'rules'=>[map { "\trm -rf {{file".$_."elif}}\n" } @cleans],'_target'=>'clean'}));
	    $m->saveTo();
	    
	} else{
	  
	}
	print ("Dependency of $groot:\n") if ($OPT{dbggraph});
	deepEdge_print(\%g,\%nodes,$groot) if ($OPT{dbggraph});
      }
}

sub usage { print("usage: $0 <infiles> [--quite|--verbose]
    --os=[win,cyg,posic]    : select dest os (default: $defos)
    --dbgtrans              : view path abs2rel transforms
    --dbggraph              : view dependency graph
    --dbgval                : debug value retrival
"); exit(1);
}
Getopt::Long::Configure(qw(bundling));
GetOptions(\%OPT,qw{
    quite|q+
    verbose|v+
    dir|d=s
    os=s@
    dbgtrans
    dbggraph
    dbgval
} ,@g_more) or usage(\*STDERR);
$bdir = ($OPT{'dir'} = $OPT{'dir'} || 'tmp');
$defos = $OPT{'os'} if (defined($OPT{'os'}));
`mkdir -p $bdir`;
print("bdir : $bdir\ndefos: [".join(",",@{$::OPT{'os'}})."]\n") if ($OPT{'verbose'});


$def = $ARGV[0];
readdef($def);


