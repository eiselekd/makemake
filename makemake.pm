package makemake;

use Data::Dumper;
use File::Basename;
use File::Path;

sub addToPhony {my ($g,$n,$r) = @_; my $e = makemake::graph::addEdge($g,$n,$::_phony,$r)->trans(['dep']); return $r;}
sub addToClean {my ($g,$n,$r) = @_; my $e = makemake::graph::addEdge($g,$n,$::_clean,$r)->trans(['dep']); return $r;}
sub addOptEdge {my ($g,$n,$r) = @_; my $e = makemake::graph::addVarEdge($g,$n,$::_opt,$r); return $r;}
sub convSlash  {my ($_fn) = @_; $_fn =~ s/[\\]/\//g; return $_fn; }

# types of edges:
#  var     : templave variable inheritance
#  build   : build-dependency 
#  alias   : alias-dependency 
#  compile : *.c->*.o transition action
#  link    : *.o->*.a link action
#  linklib : link lib reference
# type of nodes:
#  root    : a project node

$id                         = qr'[a-zA-Z0-9\._]+';
$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;
$RE_balanced_smothbrackets  = qr'(?:[\(]((?:(?>[^\(\)]+)|(??{$RE_balanced_smothbrackets}))*)[\)])'s;
$RE_balanced_brackets       = qr'(?:[\{]((?:(?>[^\{\}]+)|(??{$RE_balanced_brackets}))*)[\}])'s;

sub genmakefile {
	
	my ($g,$n,$mfn,$roota) = @_; 
	my @roota = map { $$n{$_} } @$roota; 
	my $mfile = new makemake::makefile($g,$n,{'_fname'=>$mfn});
	my %usedn = ();
	
	foreach my $root (@roota) {
		$usedn{$root->n} = 1;
		my @e = grep { !makemake::graph::isLeaf($g,$n,$_,$::bset) } map { $$_[0] } makemake::graph::deepSearch($g, $n, $root->n, $::bset);
		
		makemake::graph::addVarEdge($g,$n,makemake::graph::getOrAddNode($g,$n,'_opt'),$mfile);

		local $Data::Dumper::Maxdepth = 2;
		#print(Dumper(makemake::graph::getOrAddNode($g,$n,'_opt')));
		
		makemake::graph::addVarEdge($g,$n,$mfile,$root);
		
		$$mfile{'parts'} = [map { $$n{$_} } @e];
		
		#1: extract the transition rules
		foreach my $e (@e) {
			$usedn{$e} = 1;
			my $node = $$n{$e};
			my @r = ();
			
			#my @rp = grep { } rootPath($g,$n,$e,$::bset);
			
			my @e = makemake::graph::allEdgesFrom($g,$n,$e,$::bset);
			my @c = makemake::graph::allEdgesFrom($g,$n,$e,makemake::set::setNew(['compile']));
			my @l = makemake::graph::allEdgesFrom($g,$n,$e,makemake::set::setNew(['link','linklib']));
			my @g = makemake::graph::allEdgesFrom($g,$n,$e,makemake::set::setNew(['gen']));
			
			my @r = ();
			# todo: instead of creating tool_action from make_action, create tool_action in readdef()
			push(@r,makemake::tool::sel($g,$n,'compile',      $$n{$e},@c)) if (scalar(@c));
			push(@r,makemake::tool::sel($g,$n,$$n{$e}{'tool'},$$n{$e},@l)) if (scalar(@l));
			foreach my $gen (@g) {
				my $s = new makemake::tool($g,$n,{'txt'=>$$gen{'cmd'}});
				my $a = $s->apply($g,$n,$$n{$e},$gen);
				push(@r,$a);
			}
			
			$$n{$e}{'rules'} = [@r];
		}
		
		# 2: extract the "genflags" statments and generate makefiles
		# todo_ move outof peoject loop, only generate once
		my @a = ();
		foreach my $e (map { $$_[0] } (['_opt'], makemake::graph::deepSearch($g, $n, $root->n, $::bset))) {
			my $a_ = $$n{$e}->get('genflags'); my @i = ();
			if (defined($a_)) {
				my $node = $$n{$e};
				foreach my $a (@$a_) {
					my ($fn,$args,$gen) = @$a;
					my $i = new makemake::makefile_inc($g,$n)->merge({'_fname'=>$fn,'txt'=>$gen})->merge($args);;
					makemake::graph::addVarEdge($g,$n,$node,$i);
					push(@i,$i);
					$$i{'_fname'} = $i->doSub($fn,$mfile);
					my $m = $i->saveTo($mfile);
				}
				$node->{'genflags'} = [@i];
			}
		}
	}
	
    # 3: add 'all' target if not present
	if (!defined($usedn{'all'})) {
		my $allrule = makemake::graph::getOrAddRule($g,$n,'all');
		my $allnode = makemake::graph::getAliasRule($g,$n,$allrule);
		foreach my $r (@roota) {
			makemake::graph::addEdge($g,$n,$allnode,$r)->trans(['build','var']);
		}
		unshift(@{$$mfile{'parts'}},$allnode);
	}
	push(@{$$mfile{'parts'}},$::_phony);
	push(@{$$mfile{'parts'}},$::_clean);

	# 4: save makefile
	$mfile->saveTo($mfile);
	print("Graph of [".join(",",@$roota)."] Makefile '$mfn':\n") if ($::OPT{dbggraph} || $::OPT{verbose});
	makemake::graph::deepPrint($g,$n,[@$roota],$::bset,$mfile) if ($::OPT{dbggraph}  || $::OPT{verbose});

	# 5: generate eclipse workspaces
	foreach my $r ( map { $$n{$_} } grep { $_ ne 'all' && $$n{$_}->flagsHas(['root']) } keys(%usedn)) {
		my $id = $r->id;
		my $d = dirname($mfn)."/$id";
		`mkdir -p $d`;
		print("Generate $d (".$r->id.")\n") if (!$::OPT{'quiet'});
		
		my @enodes = grep { $$n{$_}->flagsHas(['enode']) } map { $$_[0] } makemake::graph::deepSearch($g, $n, $r->n, $::eset);
		my %vdirs = ();
		@enodes = map { my $node = $$n{$_}; $vdirs{dirname($$node{'_fname'})} = 1; $node } @enodes;
		my @vdirs = map { new makemake::eclipse_project::vfolder($g,$n,{'dir'=>$_}); } grep { $_ ne '.' } keys %vdirs;
		print(" + add vdirs [".join(",",@vdirs)."]\n") if ($::OPT{'verbose'});
		
		$ep = new makemake::eclipse_project ($g,$n,{'_fname'=>"$d/.project" })->merge({'_id'=>$id,'linkedResources'=>[@vdirs,@enodes]});
		$ec = new makemake::eclipse_cproject($g,$n,{'_fname'=>"$d/.cproject"})->merge({'_id'=>$id,'ext'=>$$r{'_ext'}});
		
		$ep->saveTo($ep);
		$ec->saveTo($ec);
	}
}
	
sub readdef {
	
	my ($g,$n,$fn) = @_; 
	my $def = makemake::utils::readfile($fn);
	my $optnode = makemake::graph::getOrAddNode($g,$n,'_opt');
	my $allnode = makemake::graph::getOrAddRule($g,$n,'all')->flags(['root','alias']);
	
	makemake::graph::addVarEdge($g,$n,$optnode,$allnode);
	
	while($def =~ /($id)\s*$RE_balanced_brackets?\s*:\s*$RE_balanced_squarebrackets/g) {
		
		my $pid = makemake::utils::trim($1);
		my $f = $pid;
		my $aproj = eval("{".makemake::utils::trim($2)."}");
		my $b = makemake::utils::trim($3);
		if ($f eq 'OPTIONS') {
			local $Data::Dumper::Maxdepth = 1;
			my $o = makemake::graph::getOrAddNode($g,$n,'_opt')->merge($aproj);
			#print Dumper($o);
			#exit(1);
			next;
		}
		if (length($b) && (($f =~ /(.+\.a)$/) || ($f =~ /(.+\.exe)$/))) {
			
			my $bf,$df,$ld;
			my $pn = $bf = makemake::utils::trim($1);
			$pn = $::OPT{'builddir'}.$pn if (!($bf =~ /[\\\/]/));

			my $tool = 'link';
			$tool = 'ar' if ($bf =~ /^.*\.a$/);
			
			my $pnode = new makemake::makefile_rule($g,$n,$pn)->flags(['root'])->merge($aproj)->flags(['opts']);
			$pnode->merge({'tool'=>$tool});
			
			my $id = $bf;
			$id =~ s/\.((?:a)|(?:exe))$//; 
			@{$pnode}{ qw/_id _ext/ } = ($id,$1);
			
			#my $_eo = addVarEdge($g,$n,getOrAddNode($g,$n,'_opt'),$pnode); #->trans(['var']);
			#my $allnode = getOrAddRule($g,$n,'all')->flags(['root']);
			
			my $rnode = $allnode; my $isalias = undef;
			if ($pn ne $bf) {
				my $_n = new makemake::makefile_rule($g,$n,$bf)->flags(['alias','phony']);
				my $_e = makemake::graph::addEdge($g,$n,$rnode,$_n)->trans(['var','alias']);
				$rnode = $_n; $isalias = 'alias';
				
				addToPhony($g,$n,$_n);

			}
			my $e0 = makemake::graph::addEdge($g,$n,$rnode,$pnode)->trans(['build','var',$isalias]);
			addToClean($g,$n,$pnode);
			
			$b =~ s/\\\n//g;
			my @b = split("[\\n]+",$b);
			for (my $i = 0; $i < scalar(@b); $i++) {
				# parse all files, a bracket can come at the end of the line
				my $b = $b[$i];
				$b = makemake::utils::trim($b);
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
						if ($c =~ /^\s*$RE_balanced_brackets/g ) {
							$b[$i] = $'; $i--; #'
							$a = $1;
							$a = eval("{$a}");
							warn $@ if $@;
							last;
						}
						$i++;
					}
				}
				#$b = $p->doSub($b);
				$b = makemake::utils::trim($b);
				# at this point we have:
				# $a == attributes, $b == file
				my $o = undef;
				my $bnode;
				
				if ($b =~ /^(.*)\.c$/ || $b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/) {
					
					$o = $::OPT{'builddir'}.basename($1).".o";
					$cc = 'gcc';
					$cc = 'g++' if ($b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/);
					
					#print("$b:$o -> $cc\n");
					
					my $onode = new makemake::makefile_rule($g,$n,$o);
					my $cnode = new makemake::makefile_rule($g,$n,$b)->flags(['enode']);
					my $_eo = new makemake::makefile_action($g,$n,$pnode,$onode)->trans(['link','var']);
					my $_ec = new makemake::makefile_action($g,$n,$onode,$cnode)->trans(['compile','var'])->merge($a);
					$onode->merge({'cc'=>$cc});
					$bnode = $cnode;

					addToClean($g,$n,$onode);
					
				} elsif ($b =~ /^(.*)\.a$/) {
					my $anode = makemake::graph::getOrAddRule($g,$n,$b);
					my $_ea = new makemake::makefile_action($g,$n,$pnode,$anode)->trans(['linklib','var'])->merge($a);
					$bnode = $anode;
				} else {
					confess("Cannot match $b\n");
				}
				if (exists($$a{'gen'})) {
					my $f = $$a{'gen'}{'from'};
					my $fnode = new makemake::makefile_rule($g,$n,$f);
					my $_eg = new makemake::makefile_action($g,$n,$bnode,$fnode)->trans(['gen','var'])->merge($$a{'gen'});
				}
			}
		}
	}
}
      
######################################################################
package makemake::makefile;
@ISA = ('makemake::template','makemake::node');
my $idx = 0;

sub new {
	my ($c,$g,$n,$s_) = @_;
	my $name = "_makefile$idx"; $idx++;
	my $s = {'_g'=>$g,'_n'=>$n,'_name'=>$name,'parts'=>[],'makeinc'=>[],'makefilesnippet'=>[]};
	bless $s,$c;
	$s->merge($s_);
	$$s{'txt'} =<<'TXTEND';
{{get-set:makefilesnippet}}
{{['wrap'=>'{{makeinclude}} ^']get-set-up:genflags.relfname}}
# parts:
{{parts}}

{{get-set:makefilesnippetpost}}
TXTEND
	confess("Multiple nodes with same name\n") if (exists($$n{$name}));
	$$n{$name} = $s;
	return $s;
}

package makemake::makefile_rule;
use Data::Dumper;
@ISA = ('makemake::template','makemake::node');
my $idx = 0;
sub new {
	my ($c,$g,$n,$name) = @_;
	$idx++;
	my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$n,'_name'=>$name,'_fname'=>$name,'rules'=>[]};
	bless $s,$c;
	$$s{'asrule'} = "{{tool}}";
	$$s{'astgt'} = "{{tgtname}}";
	$$s{'txt'}=<<'TXTEND';
# rule "{{n}}"
{{relfname}} : {{['join'=>' ']get:deps.relfname}}
{{['wrap'=>"\t^"]rules}}
TXTEND
	$$s{'etxt'}=<<'FEOF';
<link>
	<name>{{fname}}</name>
	<type>1</type>
	<locationURI>{{get:self.releprojectfname}}</locationURI>
</link>
FEOF

	$$s{'self'} = $s;
	makemake::graph::putNode($g,$n,$s);
	return $s;
}
sub tgtname {
	my ($s) = @_;
	return $s->n;

}
sub deps {
	my ($s) = @_;
	my ($g,$n) = ($$s{'_g'},$$s{'_n'});
	my @e = makemake::graph::allEdgesFrom($g,$n,$s->n,$::bset);
	my @n = makemake::graph::toNodes($g,$n,@e);
	@n = map { makemake::graph::followEdgeOrNode($g,$n,$_,$::aset); } @n;
	return [@n];
}

sub rules {
}

package makemake::makefile_action;
use Data::Dumper;
@ISA = ('makemake::template','makemake::edge');
my $idx = 0;
sub new {
	my ($c,$g,$n,$from,$to) = @_;
	$idx++;
	my $name = "_action$idx";
	my $s = {'_g'=>$g,'_n'=>$n,'_from'=>$from,'_to'=>$to};
	bless $s,$c;
	$$s{'txt'}=<<'TXTEND';
	action
TXTEND
	$$s{'asrule'}=$$s{'txt'};
	makemake::graph::putEdge($g,$n,$s);
	return $s;
}

# "genflags" instance
package makemake::makefile_inc;
@ISA = ('makemake::template','makemake::node');
my $idx = 0;
sub new {
	my ($c,$g,$n) = @_;
	my $name = "_makefile_inc_$idx"; $idx++;
	my $s = {'_g'=>$g,'_n'=>$n,'_name'=>$name,'mkincs'=>['myfile1']};
	bless $s,$c;
	confess("Multiple nodes with same name\n") if (exists($$n{$name}));
	makemake::graph::putNode($g,$n,$s);
	return $s;
}

######################################################################
package makemake::tool_action;
use Carp;
@ISA = ('makemake::template','makemake::node');
my $idx = 0;

sub new {
	my ($c,$g,$n,$tool,$obj,@srcs) = @_;
	my $name = "_tool_action_$idx";	$idx++;
	
	@srcs = map { 
	 	my @node = ($_); 
	 	if ($_->flagsHas(['alias'])) {
	 		my @g = (makemake::graph::allEdgesFrom($g,$n,$_->n,makemake::set::setNew(['alias'])));
	 		@node = makemake::graph::toNodes($g,$n,@g);
	 	}; 
	 	@node;
	} @srcs;
	
	my $s = {'_g'=>$g,'_n'=>$n,	'_name'=>$name, 'obj'=>$obj,'srcs'=>[@srcs]};
	bless $s,$c;
	$$s{'txt'} = "action";
	makemake::graph::putNode($g,$n,$s);
}

package makemake::tool;
use Carp;
use Data::Dumper;
@ISA = ('makemake::template','makemake::node');
my $idx = 0;

sub new {
	my ($c,$g,$n,$s) = @_;
	my $name = "_tool$idx";	$idx++;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	#$$s{'txt'} = 'action' if (!exists($$s{'txt'}));
	bless $s,$c;
	makemake::graph::putNode($g,$n,$s);
}

sub sel {
	my ($g,$n,$toolname,$obj,@srcs) = @_;
	$tooln = $obj->getFirst($toolname);
	confess("Cannot find tool \"$toolname\"\n") if (!defined($tooln));
	confess("Cannot find tool \"$tooln($toolname)\"\n") if (!defined($::makemake::genConfig::tools{$tooln}));
	my $tool = $::makemake::genConfig::tools{$tooln};
	return $tool->apply($g,$n,$obj,@srcs);
}

sub apply {
	my ($s,$g,$n,$obj,@srcs) = @_;
	my $a = new makemake::tool_action($g,$n,$s,$obj,makemake::graph::toNodes($g,$n,@srcs));
	makemake::graph::addVarEdge($g,$n,$obj,$a);
	makemake::graph::addVarEdge($g,$n,$s,$a); # comes after $obj
	my @k = (qw/ txt /);
	@{$a}{@k} = @{$s}{@k};
	my $c = $s->n.".".$a->n;
	map { $_->setColor($c) } ($obj,@srcs,makemake::graph::toNodes($g,$n,@srcs));
	return $a;
}

package makemake::tool_compile;
use Data::Dumper;
use Carp;
@ISA = ('makemake::tool');

sub new {
	my ($c,$g,$n,$name,$s) = @_;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	bless $s,$c;
	makemake::graph::putNode($g,$n,$s);
}

package makemake::tool_link;
use Carp;
use Data::Dumper;
@ISA = ('makemake::tool');

sub new {
	my ($c,$g,$n,$name,$s) = @_;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	bless $s,$c;
	makemake::graph::putNode($g,$n,$s);
}

######################################################################


package makemake::graph ;
use Carp;

# deep traverse, return all nodes starting from node $e. For each node call $f
# g: graph, n: nodes
sub deepSearch_f {
	my ($g,$n,$root,$f,$a,$set) = @_; my @r = (); my @p = ([$root,0]); my %h = ();
	while(scalar(@p)) {
		my ($from,$deep) = @{shift(@p)};
		if (!exists($h{$from})) {
			last if (&$f($g,$n,$a,$from,$deep));
			$h{$from}=1;
			foreach my $to (filter_set($$g{'_o'}{$from}{'_to_order'},keys %{$$g{'_g'}{$from}})) {
				foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
					if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
						push(@p, [$to, $deep+1] );
					}
				}
			}
		}
	}
}

# gather all deep traversal nodes and return them
sub deepSearch {
    my ($g,$n,$root,$set) = @_; my @r = ();
    deepSearch_f($g,$n,$root, 
		 sub { my ($g,$n,$r,$from,$deep) = @_; push(@$r,[$from]); return 0;}, 
		 \@r,$set); 
    return @r;
}

#same as deepSearch_f but with edges
sub deepSearch_e {
	my ($g,$n,$root,$f,$a,$set) = @_; my @r = (); my @p = ([$root,0]); my %h = ();
	while(scalar(@p)) {
		my ($from,$deep) = @{shift(@p)};
		foreach my $to (filter_set($$g{'_o'}{$from}{'_to_order'},keys %{$$g{'_g'}{$from}})) {
			foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
				if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
					if (!exists($h{$to})) {
						$h{$to}=1;
						last if (&$f($g,$n,$a,$e,$deep));
						push(@p, [$to, $deep+1] );
					}
				}
			}
		}
	}
}

# deep travers all edges and return a path: node-edge-node-edge...
sub deepSearchE {
    my ($g,$n,$root,$set) = @_; my @r = ();
    deepSearch_e($g,$n,$root, 
		 sub { my ($g,$n,$r,$e,$deep) = @_; push(@$r,$e); return 0;}, 
		 \@r,$set); 
	local $Data::Dumper::Maxdepth = 2;
	#print (Dumper($$n{$root}));;
	@r = ($$n{$root}, map { ($_,$$_{'_to'}) } (@r));
    return @r;
}

# deep traverse reverse direction, return all nodes starting from node $e. For each node call $f
# g: graph, n: nodes
sub deepSearchReverse_f {
	my ($g,$n,$root,$f,$a,$set) = @_; my @r = (); my @p = ([$root,0]); my %h = ();
	while(scalar(@p)) {
		my ($to,$deep) = @{shift(@p)};
		if (!exists($h{$to})) {
			last if (&$f($g,$n,$a,$to,$deep));
			$h{$to}=1;
			foreach my $from (filter_set($$g{'_o'}{$to}{'_r_from_order'}, grep { exists($$g{'_g'}{$_}{$to}) } keys %{$g})) {
				foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
					if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
						push(@p, [$from, $deep+1] );
					}
				}
			}
		}
	}
}


sub deepSearchReverse {
    my ($g,$n,$root,$set) = @_; my @r = ();
    deepSearchReverse_f($g,$n,$root, 
		 sub { my ($g,$n,$r,$from,$deep) = @_; push(@$r,[$from]); return 0;}, 
		 \@r,$set); 
	@r = map { $$n{$$_[0]} } @r; 
    return @r;
}

sub deepSearchReverse_e {
	my ($g,$n,$root,$f,$a,$set) = @_; my @r = (); my @p = ([$root,0]); my %h = ();
	$h{$root}=1;
	while(scalar(@p)) {
		my ($to,$deep) = @{shift(@p)};
		foreach my $from (filter_set($$g{'_o'}{$to}{'_r_from_order'}, grep { exists($$g{'_g'}{$_}{$to}) } keys %{$g})) {
			foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
				if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
					if (!exists($h{$from})) {
						$h{$from}=1;
						last if (&$f($g,$n,$a,$e,$deep));
						push(@p, [$from, $deep+1] );
					}
				}
			}
		}
	}
}

sub deepSearchReverseE {
    my ($g,$n,$root,$set) = @_; my @r = ();
	#print("Search for $root\n");
    deepSearchReverse_e($g,$n,$root, 
						sub { my ($g,$n,$r,$e,$deep) = @_; push(@$r,$e); return 0;}, 
		 \@r,$set);
	local $Data::Dumper::Maxdepth = 2;
	#print (Dumper($$n{$root}));;
	@r = ($$n{$root}, (map { ($_,$$_{'_from'}) } (@r))); #, $$n{$root});
    return @r;
}

sub followEdgeOrNode {
	my ($g,$n,$node,$s) = @_; 
	my @r = allEdgesFrom($g,$n,$node->n,$s);
	if (scalar(@r)) {
		@r = toNodes($g,$n,@r);
	} else {
		@r = ($node);
	}
	return @r;
}


sub shortestPath {
    my ($g,$n,$from,$to,$p,$dir,$set) = @_; 
	$dir = 1 if (!defined($dir));
	my %d = ();
	my %c = ();
	for my $a (keys %$n) {
		for my $b (keys %{$$n{$a}}) {
			$c{$a}{$b} = 1;
		}
	}
	foreach my $node (keys (%$n)) {
		$d{$node} = 'inf';
		$p{$node} = $node;
	}
	$d{$from} = 0;
	my @u = keys(%$n);
	if ($dir == 1) {
		while (@u) {
			@u = sort { ($d{$a} eq 'inf') ? 1 : (($d{$b} eq 'inf') ? -1 : ($d{$a} <=> $d{$b})); } @u;
			my $next = shift @u;
			my @n = map { $_->{'_to'}->n } allEdgesFrom($g,$n,$next,$set);
			foreach my $c (@n) {
				if (($d{$c} eq 'inf') || ($d{$c} > ($d{$next} + $c{$next}{$c}))) {
					$d{$c} = $d{$next} + $c{$next}{$c};
					$$p{$c} = $next;
				}
			}
		}
	} else {
		while (@u) {
			@u = sort { ($d{$a} eq 'inf') ? 1 : (($d{$b} eq 'inf') ? -1 : ($d{$a} <=> $d{$b})); } @u;
			my $next = shift @u;
			my @n = map { $_->{'_from'}->n } allEdgesTo($g,$n,$next,$set);
			foreach my $c (@n) {
				if (($d{$c} eq 'inf') || ($d{$c} > ($d{$next} + $c{$c}{$next}))) {
					$d{$c} = $d{$next} + $c{$c}{$next};
					$$p{$c} = $next;
				}
			}
		}
	}
	return () if (!defined($$p{$to}));
	$c = $to; my @rp = ($to);
	while ($c ne $from) { unshift(@rp, $c); $c = $$p{$c}; }
	return @rp;
}

sub allEdgesFrom {
	my ($g,$n,$root,$set) = @_; my @r = ();
	foreach my $to (filter_set($$g{'_o'}{$root}{'_to_order'},keys %{$$g{'_g'}{$root}})) {
		foreach my $e (@{$$g{'_g'}{$root}{$to}}) {
			if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
				push(@r, $e);
			}
		}
	}
	return @r;
}

sub allEdgesTo {
	my ($g,$n,$to,$set) = @_; my @r = ();
	foreach my $from (map { exists($$g{'_g'}{$_}{$to}) } filter_set($$g{'_o'}{'_from_order'}, keys %$g)) {
		foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
			if (!defined($set) || !makemake::set::setInterEmpty($$e{'_trans'},$set)) {
				push(@r, $e);
			}
		}
	}
	return @r;
}

sub assert_g_n  { my ($g,$n) = @_; confess("Expect graph and noded\n") if (!(ref($g) =~ /edges/ && ref($n) =~ /nodes/));  }
sub toNodes     { assert_g_n(@_);my ($g,$n,@e) = @_; return map { confess("Cannot find to-node: ".$$_{'_to'}->n) if (!exists($$n{$$_{'_to'}->n})); $$n{$$_{'_to'}->n} } @e; }
sub fromNodes   { assert_g_n(@_);my ($g,$n,@e) = @_; return map { confess("Cannot find from-node: ". $$_{'_from'}->n) if (!exists($$n{$$_{'_from'}->n})); $$n{$$_{'_from'}->n} } @e; }
sub isLeaf      { assert_g_n(@_);my ($g,$n,$root,$set) = @_; my @r = allEdgesFrom($g,$n,$root,$set); return (scalar(@r) == 0);  }
sub printIndent { my ($indent) = @_; my $r = ""; for (my $i = 0; $i < $indent; $i++) { $r .= ("  ");} return $r; }
sub printColor  { my ($o) = @_; if (exists($$o{'_color'})) { return ($$o{'_color'}); } else { return ("---"); }; }
sub deepPrint   {
    my ($g,$n,$roota,$set) = (shift,shift,shift,shift); 
	my @p = (); my @args = @_;
	foreach my $root (@$roota) {
		deepSearch_f($g,$n,$root,
					 sub { my ($g,$n,$r,$from,$deep) = @_; 
						   my $node = $$n{$from};
						   printIndent($deep); 
						   my $r = "";
						   if (UNIVERSAL::isa($node,'makemake::makefile_rule')) {
							   $r = $node->doSub("{{['wrap'=>'^;']rules}}",@args);
						   }
						   push(@p,[printIndent($deep)." + '$from' ","","(".printColor($node).")",$r]);
						   
						   foreach my $e (allEdgesFrom($g,$n,$from,$set)) {
							   push(@p,[printIndent($deep+1)."> ".$e->{'_to'}->n,"[".join(",", keys %{$$e{'_trans'}})."]","(".printColor($e).")"]);
						   }
						   return 0;
						   
					 }, 
					 \@r,$set); 
	}
	my $tb = Text::Table->new("id","edge","color","rules")->load(@p);
	print ($tb);
}

sub putEdge {
	my ($g,$n,$e) = @_; 
	confess("Cannot name edge nodes \n") if (!UNIVERSAL::can($$e{'_from'},'n') || !UNIVERSAL::can($$e{'_to'},'n'));
	my $from_n = $$e{'_from'}->n;  my $to_n = $$e{'_to'}->n;

	$$g{'_o'}{'_from_order'} = [] if (!exists($$g{'_o'}{_from_order}));
	$$g{'_o'}{$from_n}{'_to_order'} = [] if (!exists($$g{'_o'}{$from_n}{'_to_order'}));
	push_set($$g{'_o'}{'_from_order'},$from_n) if (!makemake::set::arcontains($$g{'_o'}{'_from_order'},$from_n));
	push_set($$g{'_o'}{$from_n}{'_to_order'},$to_n) if (!makemake::set::arcontains($$g{'_o'}{$from_n}{'_to_order'},$to_n));
	
	$$g{'_o'}{'_r_to_order'} = [] if (!exists($$g{'_o'}{'_r_to_order'}));
	$$g{'_o'}{$to_n}{'_r_from_order'} = [] if (!exists($$g{'_o'}{$to_n}{'_r_from_order'}));
	push_set($$g{'_o'}{'_r_to_order'},$to_n) if (!makemake::set::arcontains($$g{'_o'}{'_r_to_order'},$to_n));
	push_set($$g{'_o'}{$to_n}{'_r_from_order'},$from_n) if (!makemake::set::arcontains($$g{'_o'}{$to_n}{'_r_from_order'},$from_n));
	
	$$g{'_g'}{$from_n}{$to_n} = [] if (!exists($$g{$from_n}{$to_n}));
	push(@{$$g{'_g'}{$from_n}{$to_n}},$e);
	return $e;
}

sub push_set {
	my ($a, $n) = @_;
	my @a = grep { $n eq $_ } @$a;
	push(@$a, $n) if (!scalar(@a));
}

sub filter_set {
	my ($a, @n) = @_; 
	my %h = map { $_ => 1 } @n;
	return grep { $h{$_} } @$a;
}

sub addEdge {
	my ($g,$n,$from,$to) = @_; 
	confess("From or to edge undefined") if (!defined($from) || !defined($to));
	return putEdge($g,$n,new makemake::edge($g,$n,$from,$to));
}

sub addVarEdge { my ($g,$n,$from,$to) = @_; my $v = hasVarEdge($g,$n,$from,$to); return $v ? $v : addEdge($g,$n,$from,$to)->trans(['var']); }
sub hasVarEdge { my ($g,$n,$root,$set) = @_; my @r = allEdgesFrom($g,$n,$root,makemake::set::setNew(['var'])); return (shift(@r)); }

sub putNode {
	my ($g,$n,$node) = @_;
	confess("Multiple nodes with same name\n") if (exists($$n{$node->n}));
	$$n{$node->n} = $node;
	return $node;
}

sub addNode {
	my ($g,$n,$name) = @_;
	return putNode($g,$n,new makemake::node($g,$n,$name));
}
sub getOrAddNode { my ($g,$n,$name) = @_; addNode($g,$n,$name) if (!defined($$n{$name})); return $$n{$name}; }
sub getOrAddRule { my ($g,$n,$name) = @_; my $r = new makemake::makefile_rule($g,$n,$name) if (!defined($$n{$name})); return $$n{$name}; }
$alias_idx = 0;
sub getAliasRule { my ($g,$n,$r) = @_; my $nr = new makemake::makefile_rule($g,$n,$r->n."_alias_$alias_idx"); $nr->{'_fname'} = $r->{'_fname'}; $alias_idx++; $nr->flags(['alias']); return $nr; }

######################################################################

package makemake::node ;
use File::Spec;
use File::Basename;
use File::Path;
@ISA = ('makemake::hashMerge');

sub new {
	my ($class,$g,$n,$name) = @_;
	my $self = {'_g'=>$g,'_n'=>$n,'_id'=>$n,'_name'=>$name,'_fname'=>$name};
	bless $self, $class;
	return $self;
}

sub n  { return $_[0]{'_name'}; }
sub id { return $_[0]{'_id'}; }

use File::Spec;
use File::Basename;
use File::Path;

# relify $s->{_fname} to base $_[0], which is normally the
# makefile's base directory 
sub relfname {
	my ($s) = (shift); my $base = $_[0];
	my $basen = ""; my $fn = "";
	$basen = $$base{'_fname'} if (exists($$base{'_fname'}));
	$fn = $$s{'_fname'} if (exists($$s{'_fname'}));
	$fn = $$s->fname(@_) if (UNIVERSAL::can($s,'fname'));
	$basen = $$s->fname(@_) if (UNIVERSAL::can($base,'fname'));
	my $dbasen = dirname($basen);
	my $_fn = File::Spec->abs2rel(File::Spec->rel2abs($fn),File::Spec->rel2abs($dbasen));
	$_fn = $fn if ($s->flagsHas(['alias']));
	return makemake::convSlash($_fn);
}

# relify to eclipse .project
sub releprojectfname {
    my $s = shift;
    my ($p) = @_; my $cnt;
	my $f = $s->relfname(@_);
    $cnt = 0;
    $cnt++ while ($f =~ s/^\.\.[\\\/]?// );
    $f = ("PARENT-$cnt-PROJECT_LOC/".$f) if ($cnt>0);
    $f =~ s/\/\//\//g;
    $f =~ s/\/$//;
	return $f;
}

# append the directory path of the Makefile the snippet
# is called from to the filename
sub setfname {
	my ($s,$fn) = (shift,shift); my $base = $_[0];
	my $basen = "";
	$basen = $$base{'_fname'} if (exists($$base{'_fname'}));
	#$fn = $$s{'_fname'} if (exists($$s{'_fname'}));
	#$fn = $$s->fname(@_) if (UNIVERSAL::can($s,'fname'));
	$basen = $$s->fname(@_) if (UNIVERSAL::can($base,'fname'));
	my $dbasen = dirname($basen);
	$$s{'_fname'} = $dbasen."/".$fn;
	print("Relify ".$$s{'_fname'}."\n"); 
	return $$s{'_fname'};
}


package makemake::edge ;
@ISA = ('makemake::hashMerge');

sub n { return $_[0]{'_from'}->n."->".$_[0]{'_to'}->n; }
sub new {
	my ($class,$g,$n,$from,$to) = @_;
	my $self = {'_g'=>$g,'_n'=>$n,'_from'=>$from,'_to'=>$to,'_trans'=>{}};
	bless $self, $class;
	return $self;
}

package makemake::set;
sub new           { bless $_[1],$_[0]; return $_[1]; } 
sub setInter      { my ($a,$b) = @_; my %i = map { $_ => 1 } grep { exists($$b{$_}) && $$b{$_} } keys %$a; return new makemake::set(\%i); }
sub setInterEmpty { my $i = setInter(@_); return scalar(keys %$i) == 0; }
sub setNew        { my %i = map { $_ => 1 } grep { defined($_) } @{$_[0]}; return new makemake::set(\%i); }
sub arcontains    { my ($a,$n) = @_; my @a = grep { $_ eq $n } @$a;  return scalar(@a)>0; }

package makemake::edges; sub new { my ($c,$s) = @_; bless($s,$c); return $s; }
package makemake::nodes; sub new { my ($c,$s) = @_; bless($s,$c); return $s; }

######################################################################

package makemake::hashMerge;
use Carp;
use Data::Dumper;

$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;

sub get   { 
	my ($s,$f) = (shift,shift);
	local $Data::Dumper::Maxdepth = 1;	#print (" + get ".$_->n."\n");
	
	if (exists($$s{$f})) {
		#print (Dumper($$s{$f}));
		#print (" + get ".$f."\n");
	}


	if ($f =~ /^-$RE_balanced_squarebrackets>$/) {	}
	return $s if ($f eq 'self');
	return exists($$s{$f}) ? $$s{$f} : (UNIVERSAL::can($s,$f) ? $s->$f(@_) : (exists($$s{"_".$f}) ? $$s{"_".$f} : undef)); 
} 
sub trans { $_[0]->merge({'_trans'=> makemake::set::setNew($_[1])}); return $_[0];}
sub flags { $_[0]->merge({'_flags'=> makemake::set::setNew($_[1])}); return $_[0];}
sub flagsHas { my ($s,$f) = @_; return (exists($$s{'_flags'}) && (!makemake::set::setInterEmpty($$s{'_flags'},makemake::set::setNew($f)))); }
sub setColor { $_[0]->{'_color'} = $_[1]; }

sub getValsUp {
	my ($s,$n) = (shift,shift);
	my @n = makemake::graph::deepSearchE($$s{'_g'},$$s{'_n'},$s->n,makemake::set::setNew(['var']));
	my @v = map { $_->get($n,@_) } @n;
	#print($n.":".join(",",map { $_->n } @n)."\n");
	return grep { defined($_) } @v;
}

sub getVals {
	my ($s,$n) = (shift,shift);
	#print (" *get $n\n");
	my @n = makemake::graph::deepSearchReverseE($$s{'_g'},$$s{'_n'},$s->n,makemake::set::setNew(['var']));
	my @v = map { 
		local $Data::Dumper::Maxdepth = 1;
		#print (" + get ".$_->n."\n");
		#print (Dumper($_));
		
		$_->get($n,@_) } grep { defined($_) } @n;
	return grep { defined($_) } @v;
}

sub getFirstUp { my ($s,$n) = (shift,shift); my @r = $s->getValsUp($n,@_); return shift @r; }
sub getFirst   { my ($s,$n) = (shift,shift); my @r = $s->getVals($n,@_); return shift @r; }
sub getVal {
	my ($s,$n) = (shift,shift);
	return $s->get($n,@_);
}

sub merge {
	my ($self, $b, $k) = @_;
	_merge($self, $b, $k);
	return $self;
}

sub _merge {
	my ($a, $b, $k) = @_;
	my @k = keys %$b;  
	@k = @$k if (defined($k));
	foreach my $k (@k) {
		if (!exists($$a{$k})) {
			$$a{$k} = $$b{$k};
		} else {
			if (UNIVERSAL::isa($$a{$k},'HASH') &&
				(UNIVERSAL::isa($$b{$k},'makemake::set') || UNIVERSAL::isa($$a{$k},'makemake::set'))) {
				$$a{$k} = makemake::set::setNew([ keys %{$$b{$k}}, keys %{$$a{$k}} ]);
			} elsif (UNIVERSAL::isa($$b{$k},'HASH') && UNIVERSAL::isa($$a{$k},'HASH')) {
				_merge($$a{$k}, $$b{$k});
			} elsif (UNIVERSAL::isa($$b{$k},'ARRAY') && UNIVERSAL::isa($$a{$k},'ARRAY')) {
				push (@{$$a{$k}},@{$$b{$k}});
			} elsif ((!UNIVERSAL::isa($$a{$k},'ARRAY')) &&
					 (!UNIVERSAL::isa($$b{$k},'HASH')) && (!UNIVERSAL::isa($$a{$k},'HASH'))) {
				$$a{$k} = $$b{$k};
			} elsif (UNIVERSAL::isa($$a{$k},'ARRAY')) {
				push (@{$$a{$k}},$$b{$k});
			} else {
				confess("Cannot merge $k: a($$a{$k}):".(ref $$a{$k})." b($$b{$k}):".(ref $$b{$k})."\n");
			}
		}
	}
}
sub convSlash { my ($s,$_fn) = @_; $_fn =~ s/[\\]/\//gs; return $_fn; }

######################################################################

package makemake::utils;
use File::Basename;
use File::Path;

use Data::Dumper;
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub readfile {
    my ($in) = @_;
    usage(\*STDOUT) if (length($in) == 0) ;
    open IN, "$in" or die "Reading \"$in\":".$!;
    local $/ = undef;
    $m = <IN>;
    close IN;
    return $m;
}

sub writefile {
  my ($out,$re,$temp) = @_;
  my $dir = dirname($out);
  if ($dir) {
    mkpath($dir);
  }
    open OUT, ">$out" or die ($out.$!);
    print OUT ($re);
    close OUT;
}

######################################################################
# templating:
#

package makemake::template;
use Data::Dumper;
@ISA = ('node');
  
$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;
$RE_balanced_smothbrackets  = qr'(?:[\(]((?:(?>[^\(\)]+)|(??{$RE_balanced_smothbrackets}))*)[\)])'s;
$RE_balanced_brackets =       qr'(?:[\{]((?:(?>[^\{\}]+)|(??{$RE_balanced_brackets}))*)[\}])'s;
$RE_IF =                      qr'\{\{if((?:(?>(?:(?!(?:fi\}\}|\{\{if)).)+)|(??{$RE_IF}))*)fi\}\}'s;
$RE_CALL =                    qr'\{\{call((?:(?>(?:(?!(?:llac\}\}|\{\{call)).)+)|(??{$RE_CALL}))*)llac\}\}'s;
$RE_FILE =                    qr'\{\{file((?:(?>(?:(?!(?:elif\}\}|\{\{file)).)+)|(??{$RE_FILE}))*)elif\}\}'s;

sub snippetParam {
	my ($m) = (shift);
    if ($m =~ /^$RE_balanced_squarebrackets/) {
		$m = substr($m,length($&));
		return ($m,makemake::utils::trim($1));
	} else {
		return ($m,"");
	}
}

sub filesnippet {
    my ($self,$m) = (shift,shift);
    $m = makemake::utils::trim($m);
    my $p = $self->getFirst('pdir',@_);
    #if (!$self->isAlias($m)) {k
	$m = File::Spec->abs2rel(File::Spec->rel2abs($m),File::Spec->rel2abs($p));
    #}
	return makemake::convSlash($m);
}

sub callsnippet {
    my ($self,$m) = (shift,shift);
	my ($m,$n) = snippetParam($m);
	confess("Cannot find call expression\n") if (!length($n));
    my $a = $self->doSub($m,@_);
	$m = eval($n); warn $@ if $@;
    return $m;
}

sub ifsnippet {
    my ($s,$m) = (shift,shift);
    my ($m,$n) = snippetParam($m);
	confess("Cannot find if expression\n") if (!length($n));
    my $v = $s->getVal($n,@_);
    if (defined($v)) {
		return "" if (!$v);
    } else {
		return "" if ($n=~/^[a-z][a-z0-9_]*$/);
		my $r = eval($n); warn $@ if $@;
		if (!$r) {
			return "";
		}
    }
    $m =~ s/$RE_IF/$self->ifsnippet($1,@_)/gse;
    return $m;
}

sub exesnippet {
    my ($self,$m) = (shift,shift);
    return `$m`;
}

sub flatten {
	my (@v) = @_; my @r = ();
	foreach my $v (@v) {
		if (UNIVERSAL::isa($v,'ARRAY')) {
			push(@r, map { flatten($_) } @$v);
		} else {
			push(@r,$v);
		}
	}
	return @r;
}

# if $$s{$m} is an array of template objects, then call doSub on them
# as replacement text use $$o{'txt'} or the 'c' argument.
# if $$s{$m} is text replace with text
# if $$s{$m} c is an template object then call doSub
# to avoid recursion test == $s, however allow recusion with different 'c' paramter than 'txt' 
sub snippet {
    my ($s,$m) = (shift,shift);
	my ($m,$n) = snippetParam($m);
    my $pre = ""; my $post = ""; my $isset = 0;
    my $a = eval("{$n}"); warn $@ if $@; my $r = "";
	
	
	#print("$n\n".Dumper($a));
	my $v;
	if ($m =~ /^\s*([a-zA-Z0-9_\.:]+)$RE_balanced_smothbrackets/s) {
		my ($x,$sel) = ($1,$2);
		$v = UNIVERSAL::can($s,$x) ? $s->$x($s->doSub($sel,@_),@_) : 
			(exists(&$x) ? &$x($s->doSub($sel,@_),@_) : $x);
	} elsif ($m =~ /^\s*(get(?:-set)?(?:-up)?):([a-zA-Z0-9_\.]+)/) {
		my ($x,$sel) = ($1,$2); my @v = ($s);
		my $isup = ($x =~ /-up/);
		my $isset = ($x =~ /-set/);
		my $getVals = $isup ? "getValsUp" : "getVals";
		my $getFirst = $isup ? "getFirstUp" : "getFirst";
		while ($sel =~ /^([a-zA-Z0-9_]+)/) {
			my $id = $1;
			$sel =~ s/^[a-zA-Z0-9_]+\.?//;
			#printf("Retrive $id\n");
			@v = flatten( map { UNIVERSAL::can($_,$getVals) ? ($isset ? ($_->$getVals($id,@_)) : ($_->$getFirst($id,@_))) : $_ } @v);
			#print (" = ".join(",",@v)."\n");
			
		}
		if ($isset) {
			my %h = ();
			@v = grep { my $n = $_; my $e = !exists($h{$n}); $h{$n} = 1; $e } @v;
			#print("+Found ".join(",",map { UNIVERSAL::can($_,'n') ? $_->n : $_ } @v)."\n");
		}
		$v = [@v];
	} else {
		if ($$a{'gather'}) {
			$v = [$s->getVals($m,@_)] ;
		} else {
			$v = $s->getFirst($m,@_);
			local $Data::Dumper::Maxdepth = 1;
			#print("Get '$m' on ".$s->n."\n"); #:".Dumper($v)."\n");
		}
	}
    if ($$a{'wrap'}) {
		my $w = $$a{'wrap'};
		my $i = index($w,'^');
		($pre,$post) = (substr($w,0,$i),substr($w,$i+1));
    }
    return (exists($$a{'post'}) ? "" : "<undef>") if (!defined($v));
    if (UNIVERSAL::isa($v,'ARRAY')) {
		my $c = exists($$a{'c'}) ? $$a{'c'} : 'txt';
		#print ("Retrive $c\n");
		my @a = map { UNIVERSAL::can($_,'doSub') ? $_->doSub($_->get($c,@_),@_) : $_ } @{$v};
		#print ("Ar ".$s->n."[$m] $c(".scalar(@a)."):".join(" ".@a)."\n");
		my $b = $$a{'join'} || "";
      	@a = map { $pre.$_.$post } @a; 
		$r = join($b,@a);
		
    } else {
		my $c = exists($$a{'c'}) ? $$a{'c'} : 'txt'; my $cres = undef;
		$cres = $v->get($c,@_) if (UNIVERSAL::can($v,'doSub'));
		$_v = (UNIVERSAL::can($v,'doSub') && ($s != $v || $c ne 'txt' ) && defined($cres) ) ? $v->doSub($cres,@_) : $v;
		$r = $pre.$$a{'pre'}.$_v.$$a{'post'}.$post;
    }
	if (exists($$a{'trim'})) {
		$r = join("\n",map { makemake::utils::trim($_) } split('[\n]',$r));
		$r = makemake::utils::trim($r);
	}
    return $r;
}

sub doSub {
    my ($self,$m) = (shift,shift); my $cnt = 0; my $it = 0;
	my @a = @_;
    while(1) {
		my $ol = length($m);
		$cnt += ($m =~ s/$RE_IF/$self->ifsnippet($1,@a)/gsei);
		$cnt += ($m =~ s/$RE_CALL/$self->callsnippet($1,@a)/gsei);
		$cnt += ($m =~ s/$RE_FILE/$self->filesnippet($1,@a)/gsei);
		$cnt += ($m =~ s/\{$RE_balanced_brackets\}/$self->snippet($1,@a)/gse);
		$cnt += ($m =~ s/`([^`]+)`/$self->exesnippet($1,@a)/gsei);
		last if (($ol == length($m)) || $it > 4);
		$it++;
    }
    return $m;
}

sub saveTo {
	my ($s) = (shift);
	my $m = $s->doSub($$s{'txt'},@_);
	if (exists($$s{'trim'})) {
		$m = join("\n",map { makemake::utils::trim($_) } split('[\n]',$m));
	}
	my $fn = $s->{'_fname'};
	print("Writing file $fn\n") if (!$::OPT{'quiet'});
	makemake::utils::writefile($fn,$m);
	print($m) if (!$::OPT{'verbose'} && !$::OPT{'quiet'});
	return $m;
}

######################################################################

package makemake::genConfig;
use File::Temp qw/tempfile/;

%tools = 
  (
   'gnuc'=> 
   new makemake::tool_compile(\%g,\%n,'gnuc',
	  {
	   'cc' => 'gcc',
	   'txt' => '{{cc}} -c {{["wrap"=>"-I^ "]get-set:srcs.cinc}} {{["wrap"=>"\$(^) "]get-set:srcs.cflags}}  {{["wrap"=>"^ "]get:srcs.relfname}} -o {{get:obj.relfname}} '
	  }),
   'gnuld'=> 
   new makemake::tool_link(\%g,\%n,'gnuld',
	  {
	   'ld' => 'g++',
	   'txt' => '{{ld}} {{["wrap"=>"^ "]get:srcs.relfname}} {{["wrap"=>"\$(^) "]get-set:srcs.ldflags}} -o {{get:obj.relfname}} '
	  }),
   'gnuar'=> 
   new makemake::tool_link(\%g,\%n,'gnuar',
	  {
	   'ar' => 'ar',
	   'txt' => '{{ar}} cr {{get:obj.relfname}} {{["wrap"=>"^ "]get:srcs.relfname}}; ranlib {{get:obj.relfname}} '
	  })
);


sub exePerl {
    my ($e) = @_;
    my ($fh, $filename) = tempfile();
    print $fh "$e";
    close($fh);
    return `perl $filename`;
}

sub perl_opts  {
    my ($self) = @_;
    $$self{'PERL'} = "perl";
    $$self{'PERLLIB'} = makemake::convSlash(exePerl("use Config; foreach \$l ('installprivlib', 'archlibexp') { if (-f \$Config{\$l}.'/ExtUtils/xsubpp') { print \$Config{\$l}; last; }}"));
    $$self{'PERLMAKE'} = exePerl('use Config; print $Config{make};');
    $$self{'COPY'} = ($::defos =~ /win/ ) ?  'copy /Y' : 'cp';
    foreach my $m ('PERLLIB','PERLMAKE') {
		$$self{$m} =~ s/\n$//;
    } 
    return $self;
}

sub make_opts  {
    my ($self) = @_;
    $$self{'makeinclude'} = "include";
    $$self{'$^'} = "\$^";
	$$self{'osmakeext'} = 'gmake.';
}


1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
