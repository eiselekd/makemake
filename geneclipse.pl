use Getopt::Long;
use File::Basename;
use File::Path;
use FindBin qw($Bin);
use Cwd;
use Data::Dumper;
use Cwd 'abs_path';
use lib "$Bin/../lib";
require "$Bin/geneclipse_pkg.pl";

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
    my ($g,$n,$e) = @_;
    my @r = ();
    print ("Graph from $e:\n");
    deepSearch_f($g,$n,$e, sub { my ($g,$n,$r,$from,$deep) = @_; push(@$r,$from); return 0;}, \@r); 
    return @r;
}

sub deepPrint {
    my ($g,$n,$e) = @_; 
    deepSearch_f($g,$n,$e, sub { my ($g,$n,$r,$from,$deep) = @_; printIndent($deep); print(" + '$from'\n"); return 0;}, \@r); 
}

sub mergeHashRec {
    my ($a,$b) = @_;
    foreach my $k (keys %$b) {
	if (!exists($$a{$k})) {
	    $$a{$k} = $$b{$k};
	} else {
	    if (ref $$a{$k} eq ref {}) {
		mergeHashRec($$a{$k}, $$b{$k});
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
	my $f = $1;
	my $aproj = eval("{".template::trim($2)."}");
	my @cinc = @{$$aproj{CINC}} or ();
	my $genv = new genenv({});
	$$genv{'pdir'}="$dir/$f";
	$$genv{'pdirbuild'}="$dir/$f/obj";
	my @makeinc = ();
	my @cleans = ();
	
	if (defined($$aproj{'genflags'} )) {
	    my ($fn,$a,$g) = @{$$aproj{'genflags'}};
	    $fn = $genv->doSub($fn);
	    push(@makeinc,$fn);
	    #print("F:$fn\n");
	    $genv->genFlagsFile($fn,$a,$g);
	}
	foreach my $k (keys %{$aproj}) {
	    $$genv{$k} = $$aproj{$k};
	}
	
	#print Dumper($a);
	my $b = template::trim($3);
	if ($f =~ /(.+\.a)$/ && length($b)) {
	    my $n = $1;
	    $b =~ s/\\\n//g;
	    my @b = split("[\\n]+",$b);
	    #print ("$n:\n");
	    my $p = new project({'name'=>$n,'pdir'=>"$dir/$n"});
	    my $nar = $p->pdir_build("${n}");

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
		if ($b =~ /^(.*)\.c$/ || $b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/) {
		    $o = $p->pdir_build(basename(${1}).".o");
		    @{$g{$nar}{$o}}{qw(link)} = ({});
		    @{$g{$o}{$b}}{qw(compile dep)} = ({},[]);
		    my $d = new files({'file'=>$b});
		    $p->add($d);
		} elsif ($b =~ /^(.*)\.a$/) {
		    @{$g{$nar}{$b}}{qw(linklib)} = ({});
		}
		#if (defined($$a{'gen'})) {
		#print Dumper($$a{'gen'});
		$g{$b}{$b}{'gen'} = {} if (!exists($g{$b}{$b}{'gen'}));
		
		mergeHashRec($g{$b}{$b},$a);
		
		#print("::".Dumper(\%g));
		#}
		#print (Dumper(\%g));
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
	    my $cinc = "CFLAGS=\$(PERL_CCOPTS) ".join(" ",map { "-I {{file".$_."elif}} " } @cinc)."\n";
	    print("cinc:$cinc\n");
	    $m->addPart(new textsnipppet({'_up'=>$m},$cinc));
	    
	    my $brule = new makefile_rule({'_up'=>$m,'rules'=>"\tar cr \$@ \$**\n",'target'=>"$nar",'rulesdep'=>[]});
	    
	    #foreach my $_l ( @h ) {
	#	my ($ln, $_l) = @$_l;
	#	print("-------\nFrom $ln\n");
	#	foreach my $i (getNode(\%g,$ln,['gen','compile','dep'])) {
	#	    print " + ".Dumper($i);
	#	    my ($tgt,$a) = @$i;
	#	    push(@{$$brule{'rulesdep'}},$tgt);
	#	    #print ("$tgt: ".join(" ",map { $$_[0] } (@{$a}))."\n");
	#	    #print ("\tgcc \$(CFLAGS) -c -o \$@ \$^\n");
	#	    #print ("$tgt.dep: ".join(" ",map { $$_[0] } (@{$a}))."\n");
	#	    #print ("\tgcc \$(CFLAGS) -MT $tgt -MM -c -o \$@ \$^\n");
	#	    $m->addRule(new makefile_rule({'rules'=>"\tgcc \$(CFLAGS) -c -o \$@ \$**",'target'=>$tgt,'rulesdep'=>[map { $$_[0] } (@{$a})]}));
	#	    $m->addRule(new makefile_rule({'rules'=>"\tgcc \$(CFLAGS) -MT $tgt -MM -c -o \$@ \$**\n",'target'=>"$tgt.dep",'rulesdep'=>[map { $$_[0] } (@{$a})]}));
	#	}
	#    }
	    
	    my @e = deepEdge(\%g, \%nodes, $nar);
	    foreach my $e (@e) {
		my ($from,$to) = @$e; my @a = (); my @to = ();
		my @dep = ();
		my %link = (), %compile = ();
		foreach my $to (keys(%{$g{$from}})) {
		    if (exists($g{$from}{$to}{'link'})) {
			$link{$to} = 1;
		    }
		    if (exists($g{$from}{$to}{'compile'})) {
			$compile{$to} = 1;
			push(@a,"gcc \$(CFLAGS) -MT $tgt -MM -c -o \$@ \$^");
			push(@to,$to);
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
		print ("$from : ".join(" ", (keys(%link),keys(%compile), @dep) )."\n");
		my @rules = ();
		if (scalar(keys(%link))) {
		    push(@rules,("\tar cr \$@ \$**\n"));
		}
		if (scalar(keys(%compile))) {
		    push(@rules,("\tgcc \$(CFLAGS) -c -o \$@ {{\$<}}\n"));
		}
		if (scalar(@gen)) {
		    push(@rules,map { "\t$_" } @gen)
		}
		my $r = new makefile_rule({'rules'=>[@rules],'target'=>"${from}",'rulesdep'=>[keys(%link),keys(%compile),@dep]});
		$m->addPart($r);
	    }
	    
	    #$m->addRule($brule);
	    push(@cleans,"${nar}");

	    $m->addPart(new makefile_rule({'rules'=>"",'target'=>'all','rulesdep'=>["${n}"]}));
	    $m->addPart(new makefile_rule({'rules'=>[map { "\trm -rf {{file".$_."elif}}\n" } @cleans],'target'=>'clean'}));
	    $m->saveTo();
	    
	    #todo: 1. output nMake and gMake Makefiles
	    #      2. output nocyg.bat start if Make
	    
	} else{
	}
	
	
    }
}

sub usage { print("usage: $0 <infiles> [--quite|--verbose]
"); exit(1);
}
Getopt::Long::Configure(qw(bundling));
GetOptions(\%OPT,qw{
    quite|q+
    verbose|v+
    dir|d=s
} ,@g_more) or usage(\*STDERR);
$bdir = ($OPT{'dir'} = $OPT{'dir'} || 'tmp');
`mkdir -p $bdir`;

$def = $ARGV[0];
readdef($def);


