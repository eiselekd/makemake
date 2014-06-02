use File::Basename;
use File::Path;

use Data::Dumper;
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

$RE_balanced_squarebrackets = qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;
$RE_balanced_smothbrackets  = qr'(?:[\(]((?:(?>[^\(\)]+)|(??{$RE_balanced_smothbrackets}))*)[\)])'s;
$RE_balanced_brackets =       qr'(?:[\{]((?:(?>[^\{\}]+)|(??{$RE_balanced_brackets}))*)[\}])'s;
$RE_IF =                      qr'\{\{if((?:(?>(?:(?!(?:fi\}\}|\{\{if)).)+)|(??{$RE_IF}))*)fi\}\}'s;
$RE_CALL =                    qr'\{\{call((?:(?>(?:(?!(?:llac\}\}|\{\{call)).)+)|(??{$RE_CALL}))*)llac\}\}'s;
$RE_FILE =                    qr'\{\{file((?:(?>(?:(?!(?:elif\}\}|\{\{file)).)+)|(??{$RE_FILE}))*)elif\}\}'s;

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


package template;
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
		return ($m,::trim($1));
	} else {
		return ($m,"");
	}
}

sub filesnippet {
    my ($self,$m) = (shift,shift);
    $m = ::trim($m);
    my $p = $self->getFirst('pdir',@_);
    #if (!$self->isAlias($m)) {
	$m = File::Spec->abs2rel(File::Spec->rel2abs($m),File::Spec->rel2abs($p));
    #}
    return $m;
}

sub callsnippet {
    my ($self,$m) = (shift,shift);
	my ($m,$n) = snippetParam($m);
	confess("Cannot find call expression\n") if (!length($n));
    $a = $self->doSub($m,@_);
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
	my $v = $s->getFirst($m,@_);
    if ($m =~ /^get(-set)?:([a-zA-Z0-9_\.]+)/) {
		my ($isset,$sel) = ($1,$2); my @v = ($s);
		while ($sel =~ /^([a-zA-Z0-9_]+)/) {
			my $id = $1;
			$sel =~ s/^[a-zA-Z0-9_]+\.?//;
			@v = flatten( map { UNIVERSAL::can($_,'getVals') ? ($isset ? $_->getVals($id,@_) : $_->getFirst($id,@_)) : $_ } @v);
		}
		if ($isset) {
			my %h = ();
			@v = grep { my $n = $_; my $e = !exists($h{$n}); $h{$n} = 1; $e } @v;
			#print("+Found ".join(",",map { UNIVERSAL::can($_,'n') ? $_->n : $_ } @v)."\n");
		}
		$v = [@v];
	} else {
		$v = [$s->getVals($m,@_)] if ($$a{'gather'});
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
    $r = ::trim($r) if (exists($$a{'trim'})) ;
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
	print $m;
}

package genConfig;
use File::Temp qw/tempfile/;

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
    $$self{'PERLLIB'} = exePerl("use Config; foreach \$l ('installprivlib', 'archlibexp') { if (-f \$Config{\$l}.'/ExtUtils/xsubpp') { print \$Config{\$l}; last; }}");
    $$self{'PERLMAKE'} = exePerl('use Config; print $Config{make};');
    $$self{'COPY'} = ($::defos =~ /win/ ) ?  'copy /Y' : 'cp';
    foreach my $m ('PERLLIB','PERLMAKE') {
		$$self{$m} =~ s/\n$//;
    } 
    return $self;
}

1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
