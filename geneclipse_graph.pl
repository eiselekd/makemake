
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
					if (!defined($set) || !set::setInterEmpty($$e{'_trans'},$set)) {
						push(@p, [$to, $deep+1] );
					}
				}
			}
		}
	}
}

sub deepSearch {
    my ($g,$n,$root,$set) = @_; my @r = ();
    deepSearch_f($g,$n,$root, 
		 sub { my ($g,$n,$r,$from,$deep) = @_; push(@$r,[$from]); return 0;}, 
		 \@r,$set); 
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
			foreach my $from (filter_set($$g{'_o'}{'_from_order'},grep { exists($$g{'_g'}{$_}{$to}) } keys %{$g})) {
				foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
					if (!defined($set) || !set::setInterEmpty($$e{'_trans'},$set)) {
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
		foreach my $from (filter_set($$g{'_o'}{'_from_order'},grep { exists($$g{'_g'}{$_}{$to}) } keys %{$g})) {
			foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
				if (!defined($set) || !set::setInterEmpty($$e{'_trans'},$set)) {
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
	@r = ($$n{$root}, map { ($_,$$_{'_from'}) } (@r)); #, $$n{$root});
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
			my @n = map { $_->{'_to'}->n } ::allEdgesFrom($g,$n,$next,$set);
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
			my @n = map { $_->{'_from'}->n } ::allEdgesTo($g,$n,$next,$set);
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
			if (!defined($set) || !set::setInterEmpty($$e{'_trans'},$set)) {
				push(@r, $e);
			}
		}
	}
	return @r;
}

sub allEdgesTo {
	my ($g,$n,$to,$set) = @_; my @r = ();
	foreach my $from (filter_set($$g{'_o'}{'_from_order'},map { exists($$g{'_g'}{$_}{$to}) } keys %$g)) {
		foreach my $e (@{$$g{'_g'}{$from}{$to}}) {
			if (!defined($set) || !set::setInterEmpty($$e{'_trans'},$set)) {
				push(@r, $e);
			}
		}
	}
	return @r;
}

sub toNodes     { my ($g,$n,@e) = @_; return map { confess("Cannot find to-node") if (!exists($$n{$$_{'_to'}->n})); $$n{$$_{'_to'}->n} } @e; }
sub fromNodes   { my ($g,$n,@e) = @_; return map { confess("Cannot find from-node") if (!exists($$n{$$_{'_to'}->n})); $$n{$$_{'_from'}->n} } @e; }
sub isLeaf      { my ($g,$n,$root,$set) = @_; my @r = allEdgesFrom($g,$n,$root,$set); return (scalar(@r) == 0);  }
sub printIndent { my ($indent) = @_; my $r = ""; for (my $i = 0; $i < $indent; $i++) { $r .= ("  ");} return $r; }
sub printColor  { my ($o) = @_; if (exists($$o{'_color'})) { return ($$o{'_color'}); } else { return ("---"); }; }
sub deepPrint   {
    my ($g,$n,$root,$set) = (shift,shift,shift,shift); 
	my @p = (); my @args = @_;
    deepSearch_f($g,$n,$root,
				 sub { my ($g,$n,$r,$from,$deep) = @_; 
					   my $node = $$n{$from};
					   printIndent($deep); 
					   my $r = "";
					   if (UNIVERSAL::isa($node,'makefile_rule')) {
						   $r = $node->doSub("{{['wrap'=>'^;']rules}}",@args);
					   }
					   push(@p,[printIndent($deep)." + '$from' ","","(".printColor($node).")",$r]);
					   
					   foreach my $e (allEdgesFrom($g,$n,$from,$set)) {
						   push(@p,[printIndent($deep+1)."> ".$e->{'_to'}->n,"[".join(",", keys %{$$e{'_trans'}})."]","(".printColor($e).")"]);
					   }
					   return 0;
			   
		   }, 
				 \@r,$set); 
	
	my $tb = Text::Table->new("id","edge","color","rules")->load(@p);
	print ($tb);
}

sub putEdge {
	my ($g,$n,$e) = @_; 
	my $from_n = $$e{'_from'}->n;  my $to_n = $$e{'_to'}->n;
	$$g{'_o'}{'_from_order'} = [] if (!exists($$g{'_o'}{_from_order}));
	$$g{'_o'}{$from_n}{'_to_order'} = [] if (!exists($$g{'_o'}{$from_n}{'_to_order'}));
	$$g{'_g'}{$from_n}{$to_n} = [] if (!exists($$g{$from_n}{$to_n}));
	push_set($$g{'_o'}{'_from_order'},$from_n);
	push_set($$g{'_o'}{$from_n}{'_to_order'},$to_n);
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
	my %h = map { $_ => 1 } @$a;
	return grep { $h{$_} } @n;
}

sub addEdge {
	my ($g,$n,$from,$to) = @_; 
	confess("From or to edge undefined") if (!defined($from) || !defined($to));
	return putEdge($g,$n,new edge($g,$n,$from,$to));
}

sub addVarEdge { my ($g,$n,$from,$to) = @_; my $v = hasVarEdge($g,$n,$from,$to); return $v ? $v : addEdge($g,$n,$from,$to)->trans(['var']); }
sub hasVarEdge { my ($g,$n,$root,$set) = @_; my @r = allEdgesFrom($g,$n,$root,set::setNew(['var'])); return (shift(@r)); }

sub putNode {
	my ($g,$n,$node) = @_;
	confess("Multiple nodes with same name\n") if (exists($$n{$node->n}));
	$$n{$node->n} = $node;
	return $node;
}

sub addNode {
	my ($g,$n,$name) = @_;
	return putNode($g,$n,new node($g,$n,$name));
}
sub getOrAddNode { my ($g,$n,$name) = @_; addNode($g,$n,$name) if (!defined($$n{$name})); return $$n{$name}; }
sub getOrAddRule { my ($g,$n,$name) = @_; my $r = new makefile_rule($g,$n,$name) if (!defined($$n{$name})); return $$n{$name}; }

package node ;
use File::Spec;
@ISA = ('hashMerge');

sub new {
	my ($class,$g,$n,$name) = @_;
	my $self = {'_g'=>$g,'_n'=>$n,'_name'=>$name,'_fname'=>$name};
	bless $self, $class;
	return $self;
}

sub n { return $_[0]{'_name'}; }

sub relfname {
	my ($s) = (shift); my $base = $_[0];
	my $basen = ""; my $fn = "";
	$basen = $$base{'_fname'} if (exists($$base{'_fname'}));
	$fn = $$s{'_fname'} if (exists($$s{'_fname'}));
	$fn = $$s->fname(@_) if (UNIVERSAL::can($s,'fname'));
	$basen = $$s->fname(@_) if (UNIVERSAL::can($base,'fname'));
	$_fn = File::Spec->abs2rel(File::Spec->rel2abs($fn),File::Spec->rel2abs($basen));
	return $_fn;
}

package edge ;
@ISA = ('hashMerge');

sub new {
	my ($class,$g,$n,$from,$to) = @_;
	my $self = {'_g'=>$g,'_n'=>$n,'_from'=>$from,'_to'=>$to,'_trans'=>{}};
	bless $self, $class;
	return $self;
}

package set;
sub new           { bless $_[1],$_[0]; return $_[1]; } 
sub setInter      { my ($a,$b) = @_; my %i = map { $_ => 1 } grep { exists($$b{$_}) && $$b{$_} } keys %$a; return new set(\%i); }
sub setInterEmpty { my $i = setInter(@_); return scalar(keys %$i) == 0; }
sub setNew        { my %i = map { $_ => 1 } @{$_[0]}; return new set(\%i); }

package hashMerge;
use Carp;

$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;

sub get   { 
	my ($s,$f) = (shift,shift);
	if ($f =~ /^-$RE_balanced_squarebrackets>$/) {
		
	}
	return exists($$s{$f}) ? $$s{$f} : (UNIVERSAL::can($s,$f) ? $s->$f(@_) : undef); 
} 
sub trans { $_[0]->merge({'_trans'=> set::setNew($_[1])}); return $_[0];}
sub flags { $_[0]->merge({'_flags'=> set::setNew($_[1])}); return $_[0];}
sub setColor { $_[0]->{'_color'} = $_[1]; }

sub getVals {
	my ($s,$n) = (shift,shift);
	my @n = ::deepSearchReverseE($$s{'_g'},$$s{'_n'},$s->n,set::setNew(['var']));
	my @v = map { $_->get($n,@_) } @n;
	return grep { defined($_) } @v;
}
sub getFirst { my ($s,$n) = (shift,shift); my @r = $s->getVals($n,@_); return shift @r; }
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
				(UNIVERSAL::isa($$b{$k},'set') || UNIVERSAL::isa($$a{$k},'set'))) {
				$$a{$k} = set::setNew([ keys %{$$b{$k}}, keys %{$$a{$k}} ]);
			} elsif (UNIVERSAL::isa($$b{$k},'HASH') && UNIVERSAL::isa($$a{$k},'HASH')) {
				_merge($$a{$k}, $$b{$k});
			} elsif (UNIVERSAL::isa($$b{$k},'ARRAY') && UNIVERSAL::isa($$a{$k},'ARRAY')) {
				push (@{$$a{$k}},@{$$b{$k}});
			} elsif (UNIVERSAL::isa($$a{$k},'ARRAY')) {
				push (@{$$a{$k}},$$b{$k});
			} else {
				confess("Cannot merge $k: a($$a{$k}):".(ref $$a{$k})." b($$b{$k}):".(ref $$b{$k})."\n");
			}
		}
	}
}

1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
