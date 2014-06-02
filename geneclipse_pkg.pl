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
	
	my ($g,$n,$root) = @_; 
	
	my @e = grep { !isLeaf($g,$n,$_,$::bset) } map { $$_[0] } deepSearch($g, $n, $root, $::bset);
	
	my $mfile = new makefile($g,$n);
	::addVarEdge($g,$n,getOrAddNode($g,$n,'_opt'),$mfile);
	
	$$mfile{'parts'} = [map { $$n{$_} } @e];
	
	foreach my $e (@e) {
		my $node = $$n{$e};
		
		#print($node->n."\n");
		my @r = ();
		
		#my @rp = grep { } rootPath($g,$n,$e,$::bset);
		#@rp
		
		my @e = allEdgesFrom($g,$n,$e,$::bset);
		
		my @c = allEdgesFrom($g,$n,$e,set::setNew(['compile']));
		my @l = allEdgesFrom($g,$n,$e,set::setNew(['link','linklib']));
		my @g = allEdgesFrom($g,$n,$e,set::setNew(['gen']));
		
		my @r = ();
		push(@r,tool::sel($g,$n,'compile',$$n{$e},@c)) if (scalar(@c));
		push(@r,tool::sel($g,$n,'ar'     ,$$n{$e},@l)) if (scalar(@l));
		foreach my $gen (@g) {
			my $s = new tool($g,$n,{'txt'=>$$gen{'cmd'}});
			my $a = $s->apply($g,$n,$$n{$e},$gen);
			push(@r,$a);
		}
		
		
		# as compile rules use the to-node
		#@c = ::toNodes($g,$n,@c);
		#print("Scalar ".scalar(@c)."\n");
		#push(@r,map { $$node{'tool'} = $compiler; $_ } @c);
		## as compile rules use self
		#if (scalar(@l)) {
		#	$$node{'tool'} = $linker; push(@r,$node);
		#}
		
		$$n{$e}{'rules'} = [@r];
		
		
	}
	
	$mfile->saveTo($mfile);
	print("Graph of $root:\n") if ($::OPT{dbggraph});
	deepPrint($g,$n,$root,$::bset,$mfile) if ($::OPT{dbggraph});
}


sub readdef {
	
	my ($g,$n,$fn) = @_; 
	my $def = readfile($fn);
	my $optnode = getOrAddNode($g,$n,'_opt');
	my $allnode = getOrAddRule($g,$n,'all')->flags(['root']);
	
	addVarEdge($g,$n,$optnode,$allnode);
	
	while($def =~ /($id)\s*$RE_balanced_brackets?\s*:\s*$RE_balanced_squarebrackets/g) {
		
		my $pid = trim($1);
		my $f = $pid;
		my $aproj = eval("{".trim($2)."}");
		my $b = trim($3);
		if ($f eq 'OPTIONS') {
			getOrAddNode($g,$n,'_opt')->merge($aproj);
			next;
		}
		if (length($b) && (($f =~ /(.+\.a)$/) || ($f =~ /(.+\.exe)$/))) {
			
			my $bf;
			my $pn = $bf = trim($1);
			my $pnode = new makefile_rule($g,$n,$pn)->flags(['root'])->merge($aproj)->flags(['opts']);
			
			#my $_eo = addVarEdge($g,$n,getOrAddNode($g,$n,'_opt'),$pnode); #->trans(['var']);
			#my $allnode = getOrAddRule($g,$n,'all')->flags(['root']);
			
			my $e0 = addEdge($g,$n,$allnode,$pnode)->trans(['build','var']);
			
			if ($pn ne $bf) {
				my $_n = new makefile_rule($g,$n,$nf);
				my $_e = addEdge($g,$n,$pnode,$_n)->trans(['alias','var']);
				$pnode = $_n;
			}
			
			$b =~ s/\\\n//g;
			my @b = split("[\\n]+",$b);
			for (my $i = 0; $i < scalar(@b); $i++) {
				# parse all files, a bracket can come at the end of the line
				my $b = $b[$i];
				$b = trim($b);
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
				$b = trim($b);
				# at this point we have:
				# $a == attributes, $b == file
				my $o = undef;
				my $bnode;
				
				if ($b =~ /^(.*)\.c$/ || $b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/) {
					
					$o = basename($1).".o";
					$cc = 'gcc';
					$cc = 'g++' if ($b =~ /^(.*)\.cpp$/ || $b =~ /^(.*)\.cc$/);
					
					#print("$b:$o\n");
					my $onode = new makefile_rule($g,$n,$o);
					my $cnode = new makefile_rule($g,$n,$b);
					my $_eo = new makefile_action($g,$n,$pnode,$onode)->trans(['link','var']);
					my $_ec = new makefile_action($g,$n,$onode,$cnode)->trans(['compile','var'])->merge($a);
					$onode->merge({'cc'=>$cc});
					$bnode = $cnode;
				} elsif ($b =~ /^(.*)\.a$/) {
					my $anode = getOrAddRule($g,$n,$b);
					my $_ea = new makefile_action($g,$n,$pnode,$anode)->trans(['linklib','var'])->merge($a);
					$bnode = $anode;
				} else {
					confess("Cannot match $b\n");
				}
				if (exists($$a{'gen'})) {
					my $f = $$a{'gen'}{'from'};
					my $fnode = new makefile_rule($g,$n,$f);
					my $_eg = new makefile_action($g,$n,$bnode,$fnode)->trans(['gen','var'])->merge($$a{'gen'});
				}
			}
		}
	}
}
      
package makefile;
@ISA = ('template','node');
my $idx = 0;

sub new {
	my ($c,$g,$n) = @_;
	my $name = "_makefile$idx"; $idx++;
	my $s = {'_g'=>$g,'_n'=>$n,'_name'=>$name,'parts'=>[],'makeinc'=>[],'makefilesnippet'=>[]};
	bless $s,$c;
	$$s{'txt'} =<<'TXTEND';
# parts:
{{parts}}
TXTEND
	confess("Multiple nodes with same name\n") if (exists($$n{$name}));
	$$n{$name} = $s;
	return $s;
}

package makefile_rule;
use Data::Dumper;
@ISA = ('template','node');
my $idx = 0;
sub new {
	my ($c,$g,$n,$name) = @_;
	$idx++;
	my $s = {'_g'=>$g,'_n'=>$n,'_name'=>$name,'_fname'=>$name,'rules'=>[]};
	bless $s,$c;
	$$s{'asrule'} = "{{tool}}";
	$$s{'astgt'} = "{{tgtname}}";
	$$s{'txt'}=<<'TXTEND';
# rule "{{n}}"
{{[c=>tgtname]self}} : {{['join'=>' ','c'=>'astgt']deps}}
{{['wrap'=>"\t^"]rules}}
TXTEND
	$$s{'self'} = $s;
	::putNode($g,$n,$s);
	return $s;
}
sub tgtname {
	my ($s) = @_;
	return $s->n;

}
sub deps {
	my ($s) = @_;
	my ($g,$n) = ($$s{'_g'},$$s{'_n'});
	my @e = ::allEdgesFrom($g,$n,$s->n,$::bset);
	my %k = map { $$_{'_to'}->n => 1 } @e;
	return [map { $$n{$_} } keys %k];
}
sub rules {
}

package makefile_action;
use Data::Dumper;
@ISA = ('template','edge');
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
	::putEdge($g,$n,$s);
	return $s;
}

package tool_action;
use Carp;
@ISA = ('template','node');
my $idx = 0;


sub new {
	my ($c,$g,$n,$tool,$obj,@srcs) = @_;
	my $name = "_tool_action_$idx";	$idx++;
	my $s = {'_g'=>$g,'_n'=>$n,	'_name'=>$name, 'obj'=>$obj,'srcs'=>[@srcs]};
	bless $s,$c;
	$$s{'txt'} = "action";
	::putNode($g,$n,$s);
}

package tool;
use Carp;
use Data::Dumper;
@ISA = ('template','node');
my $idx = 0;

sub new {
	my ($c,$g,$n,$s) = @_;
	my $name = "_tool$idx";	$idx++;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	#$$s{'txt'} = 'action' if (!exists($$s{'txt'}));
	bless $s,$c;
	::putNode($g,$n,$s);
}

sub apply {
	my ($g,$n,$obj,@srcs) = @_;
	
	return undef;
}

sub sel {
	my ($g,$n,$toolname,$obj,@srcs) = @_;
	$tooln = $obj->getFirst($toolname);
	confess("Cannot find tool \"$toolname\"\n") if (!defined($tooln));
	confess("Cannot find tool \"$tool\"\n") if (!defined($::tools{$tooln}));
	my $tool = $::tools{$tooln};
	return $tool->apply($g,$n,$obj,@srcs);
}

sub apply {
	my ($s,$g,$n,$obj,@srcs) = @_;
	my $a = new tool_action($g,$n,$s,$obj,::toNodes($g,$n,@srcs));
	::addVarEdge($g,$n,$s,$a);
	::addVarEdge($g,$n,$obj,$a);
	my @k = (qw/ txt /);
	@{$a}{@k} = @{$s}{@k};
	my $c = $s->n.".".$a->n;
	map { $_->setColor($c) } ($obj,@srcs,::toNodes($g,$n,@srcs));
	return $a;
}

package tool_compile;
use Data::Dumper;
use Carp;
@ISA = ('tool');

sub new {
	my ($c,$g,$n,$name,$s) = @_;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	bless $s,$c;
	::putNode($g,$n,$s);
}

#sub apply {
#	my ($s,$g,$n,$obj,@srcs) = @_;
#	my @e = ::allEdgesFrom($g,$n,$obj->n,set::setNew(['compile']));
#	my $a = new tool_action($g,$n,$s,$obj,::toNodes($g,$n,@e));
#	::addVarEdge($g,$n,$s,$a);
#	::addVarEdge($g,$n,$obj,$a);
#	my @k = (qw/ txt /);
#	@{$a}{@k} = @{$s}{@k};
#	my $c = $s->n.".".$a->n;
#	map { $_->setColor($c) } ($obj,::allEdgesFrom($g,$n,$obj->n,set::setNew(['compile'])));
#	return $a;
#}

package tool_link;
use Carp;
use Data::Dumper;
@ISA = ('tool');

sub new {
	my ($c,$g,$n,$name,$s) = @_;
	@{$s}{qw/_g _n _name/} = ($g, $n, $name);
	bless $s,$c;
	::putNode($g,$n,$s);
}

#sub apply {
#	my ($s,$g,$n,$obj,@srcs) = @_;
#	my $a = new tool_action($g,$n,$s,$obj,@srcs);
#	::addVarEdge($g,$n,$s,$a);
#	::addVarEdge($g,$n,$obj,$a);
#	my @k = (qw/ txt /);
#	@{$a}{@k} = @{$s}{@k};
#	my $c = $s->n.".".$a->n;
#	map { $_->setColor($c) } ($obj,@e,::toNodes($g,$n,@e));
#	return $a;
#}




1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
  
