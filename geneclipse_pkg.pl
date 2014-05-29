package geneclipse;
use File::Basename;
use File::Path;

sub hasos {
  my ($o) = @_;
  $o = lc($o);
  return 1 if (!exists($::OPT{'os'}));
  if (ref $::OPT{'os'} eq ref []) {
    my @e = grep { my $o0 = lc($_); $o =~ /$o0/ } @{$::OPT{'os'}};
    #print("Found $o ".scalar(@e)."\n");
    return scalar(@e) ;
  }
  return lc($::OPT{'os'}) eq $o;
}

sub appendTail {
  my ($self,$a) = @_;
  my $p = $self;
  while (defined($$p{'_up'})) {
    $p  = $$p{'_up'};
  }
  $$p{'_up'} = $a;
}

sub remove {
  my ($self,$a) = @_;
  my $p = $self;
  while(defined($$p{'_up'})) {
    if ($$p{'_up'} == $a) {
      $$p{'_up'} = undef;
      last;
    }
    $p  = $$p{'_up'};
  }
}

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

sub getFilename {
  my ($self,$d) = @_;
  my $of = $$self{'fname'};
  if (defined($d)) {
    if (! -d $d) {
      $of = basename($d);
      $d = dirname($d);
    }
  } else {
    $d = $$self{'pdir'} || ".";
  }
  $$self{'pdir'} = $d;
  $of = $d."/".$of;
  my $m = "";
  $of = $self->doSub($of);
  return $of;
}

sub saveTo {
  my $self = shift;
  my ($d) = @_;
  my $of = $self->getFilename(@_);
  writefile($of, $m = $self->subTemplate());
  #print "Write to $of:".$m;
}

package template;

use Data::Dumper;

$RE_balanced_squarebrackets =    qr'(?:[\[]((?:(?>[^\[\]]+)|(??{$RE_balanced_squarebrackets}))*)[\]])'s;
$RE_balanced_smothbrackets =     qr'(?:[\(]((?:(?>[^\(\)]+)|(??{$RE_balanced_smothbrackets}))*)[\)])'s;
$RE_balanced_brackets =          qr'(?:[\{]((?:(?>[^\{\}]+)|(??{$RE_balanced_brackets}))*)[\}])'s;
$RE_IF =                         qr'\{\{if((?:(?>(?:(?!(?:fi\}\}|\{\{if)).)+)|(??{$RE_IF}))*)fi\}\}'s;
$RE_CALL =                       qr'\{\{call((?:(?>(?:(?!(?:llac\}\}|\{\{call)).)+)|(??{$RE_CALL}))*)llac\}\}'s;
$RE_FILE =                        qr'\{\{file((?:(?>(?:(?!(?:elif\}\}|\{\{file)).)+)|(??{$RE_FILE}))*)elif\}\}'s;

sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub convDos {
    my ($self,$m) = @_;
    return $m;
}

sub convPosix {
    my ($self,$m) = @_;
    $m =~ s/\\/\//g;
    return $m;
}

sub pdir {
  my ($self,$n) = @_;
  my $p = $self->getValue('pdir');
  return $p."/".$n;
}
sub pdir_build {
  my ($self,$n) = @_;
  my $p = $self->getValue('pdir');
  return $p."/".$n;
}

sub pdir_lib {
  my ($self,$n) = @_;
  my $p = $self->getValue('dir');
  return $p."/lib/$n";
}


sub filesnippet {
    my ($self,$m) = @_;
    $m = trim($m);
    my $p = $self->getValue('pdir');
    $m = File::Spec->abs2rel(File::Spec->rel2abs($m),File::Spec->rel2abs($p));
    return $m;
}

sub callsnippet {
    my ($self,$m) = @_;
    $m =~ $RE_balanced_squarebrackets or croak("Cannot find bracket");
    $m = substr($m,length($&));
    my $n = trim($1);
    $m = $self->doSub($m);
    if (length($n)) {
	#print ("Eval:$n\n");
	$m = eval($n);
	warn $@ if $@;
    }
    return $m;
}

sub ifsnippet {
    my ($self,$m) = @_;
    $m =~ $RE_balanced_squarebrackets or croak("Cannot find bracket");
    $m = substr($m,length($&));
    my $n = trim($1);
    my $v = $self->getValue($n);
    if (defined($v)) {
      return "" if (!$v);
    } else {
      return "" if ($n=~/^[a-z][a-z0-9_]*$/);
      my $r = eval($n);
      warn $@ if $@;
      if (!$r) {
	return "";
      }
    }
    $m =~ s/$RE_IF/$self->ifsnippet($1)/gse;
    return $m;
}

sub exesnippet {
    my ($self,$m) = @_;
    #print ("Try execute '$m'\n");
    return `$m`;
}

sub getValue {
    my ($self,$m,$r) = @_;
    $m = trim($m);
    #print ("resolve $m\n");
    $m = $self->doSub($m);
    if (exists($$self{$m})) {
      return $$self{$m} if (!defined($r));
      if (ref $$self{$m} eq 'ARRAY') {
	push(@$r,@{$$self{$m}});
      } else {
	push(@$r,$$self{$m});
      }
    }
    if (defined($$self{'_up'}) && (ref $$self{'_up'} eq ref [])) {
      foreach my $a (@{$$self{'_up'}}) {
	my $v = $a->getValue($m,$r);
	return $v if (defined($v) && !defined($r));
      }
    } else {
      if (defined($$self{'_up'})){
	my $v = $$self{'_up'}->getValue($m,$r);
	return $v if (!defined($r));
      }
    }
    return undef;
}

sub snippet {
    my ($self,$m) = @_;
    my $a = {}; my $r = "";
    if ($m =~ /\s*$RE_balanced_squarebrackets/) {
	$m = substr($m,length($&));
	$a = eval("{$1}");
	#print (Dumper($a));
    }
    $m = trim($m);
    my $v = $self->getValue($m); 
    if ($$a{'gather'}) {
      $v = [];
      $self->getValue($m,$v);
      $v = [grep { defined($_) } @$v];
      print("----\n".join(",",@$v)."\n");
    }
    my $pre = "",$post = "";
    if ($$a{'wrap'}) {
      my $w = $$a{'wrap'};
      my $i = index($w,'^');
      ($pre,$post) = (substr($w,0,$i), substr($w,$i+1));
    }
    return (exists($$a{'post'}) ? "" : "<undef>") if (!defined($v));
    if (ref $v eq 'ARRAY') {
	my @a = map { UNIVERSAL::can($_,'subTemplate') ? $_->subTemplate() : $_ } @{$v};
	my $b = $$a{'join'} || "";
      	@a = map { $pre.$_.$post } @a; 
	$r = join($b,@a);
    } else {
	$r = $pre.$$a{'pre'}.$v.$$a{'post'}.$post;
    }
    $r = trim($r) if (exists($$a{'trim'})) ;
    return $r;
		      
}

sub doSub {
    my ($self,$m) = @_; my $cnt = 0;
    $cnt += ($m =~ s/$RE_IF/$self->ifsnippet($1)/gsei);
    $cnt += ($m =~ s/$RE_CALL/$self->callsnippet($1)/gsei);
    $cnt += ($m =~ s/$RE_FILE/$self->filesnippet($1)/gsei);
    $cnt += ($m =~ s/\{$RE_balanced_brackets\}/$self->snippet($1)/gse);
    $cnt += ($m =~ s/`([^`]+)`/$self->exesnippet($1)/gsei);
    return $m;
}

sub subTemplate {
    my ($self) = @_;
    my $m = $self->getRaw();
    return $self->doSub($m);
}

sub genFlagsFile {
    my ($self,$fn,$a,$g) = @_;
    my $g2 = $self->doSub($g);
    $g2 = join("\n",map { template::trim($_) } split("\\n",$g2)) if ($$a{'trim'});
    geneclipse::writefile($fn, $g2);
}

package optsnippet;
@ISA = ('template','geneclipse');
sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    return $self;
}

package textsnipppet;
@ISA = ('template','geneclipse');
sub new {
    my ($class,$self,$c) = @_;
    bless $self, $class;
    $$self{'_c'} = $c;
    return $self;
}
sub getRaw {  my ($self) = @_; return $$self{'_c'}; }
sub setProjectPath { my ($self,$p) = @_; my $cnt;  $$self{'pdir'} = $p; }


package relResources;
@ISA = ('template');

sub setProjectPath {
  my ($self,$p) = @_; my $cnt;
  my $d = $self->dir();
  $$self{'pdir'} = $p;
  #print("p0:".File::Spec->rel2abs($self->dir())."\n");
  #print("p1:".File::Spec->rel2abs($p)."\n");
  $$self{'dir'} = File::Spec->abs2rel(File::Spec->rel2abs($self->dir()),File::Spec->rel2abs($p));
  #print(" =:".$$self{'dir'}."\n");
}

sub dir {
  my ($self) = @_;
  return $$self{'dir'} if defined($$self{'dir'});
  return ".";
}

package linkedResources;
@ISA = ('template','relResources');
use File::Spec;

sub setProjectPath {
    my $self = shift;
    my ($p) = @_; my $cnt;
    $self->relResources::setProjectPath(@_);
    $cnt = 0;
    $cnt++ while ((($$self{'dir'} =~ s/^\.\.[\\\/]?// )));
    ($$self{'dir'} = "PARENT-$cnt-PROJECT_LOC/".$$self{'dir'}) if ($cnt>0);
    $$self{'dir'} =~ s/\/\//\//g;
    $$self{'dir'} =~ s/\/$//;
}

package folders;
@ISA = ('template','linkedResources');

$d=<<'DEOF';
<link>
	<name>{{vdir}}</name>
	<type>2</type>
	<locationURI>virtual:/virtual</locationURI>
</link>
DEOF

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    return $self;
}

sub getRaw { return $d; }


package files;
@ISA = ('template','linkedResources');
use File::Basename;
use File::Path;

$f=<<'FEOF';
<link>
	<name>{{if[$$self{vdir} ne '.'] {{vdir}}/fi}}{{filename}}</name>
	<type>1</type>
	<locationURI>{{dir}}/{{filename}}</locationURI>
</link>
FEOF

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    my $f = $$self{'file'};
    my $fn = basename($f);
    $$self{'filename'} = $fn;
    $$self{'vdir'} = $$self{'dir'} = dirname($f);
    return $self;
}
sub getRaw { return $f; }

package project;
@ISA = ('template','geneclipse');

$p=<<'PEOF';
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
  <name>{{name}}</name>
  <comment></comment>
  <projects>
  </projects>
  <buildSpec>
    <buildCommand>
      <name>org.eclipse.cdt.managedbuilder.core.genmakebuilder</name>
      <triggers>clean,full,incremental,</triggers>
      <arguments>
      </arguments>
    </buildCommand>
    <buildCommand>
      <name>org.eclipse.cdt.managedbuilder.core.ScannerConfigBuilder</name>
      <triggers>full,incremental,</triggers>
      <arguments>
      </arguments>
    </buildCommand>
  </buildSpec>
  <natures>
    <nature>org.eclipse.cdt.core.cnature</nature>
    <nature>org.eclipse.cdt.core.ccnature</nature>
    <nature>org.eclipse.cdt.managedbuilder.core.managedBuildNature</nature>
    <nature>org.eclipse.cdt.managedbuilder.core.ScannerConfigNature</nature>
  </natures>
  <linkedResources>
  {{linkedResources}}
  </linkedResources>
</projectDescription>
PEOF

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    $$self{'fname'} = '.project';
    $$self{'linkedResources'} = [] if (!defined($$self{'linkedResources'}));
    return $self;
}
sub getRaw { return $p; }
sub add {
  my ($self,$o) = @_;
  if (UNIVERSAL::isa($o, 'linkedResources')) {
    push(@{$$self{'linkedResources'}},$o);
  }
}
sub subTemplate {
  my ($self) = @_;
  my $p = ".";
  $p = $$self{'pdir'} if defined($$self{'pdir'});
  foreach my $e (@{$$self{'linkedResources'}}) {
    $e->setProjectPath($p);
  }
  $self->template::subTemplate();
}

package cproject;
@ISA = ('template','geneclipse');


$c=<<'CEOF';
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?fileVersion 4.0.0?>

<cproject storage_type_id="org.eclipse.cdt.core.XmlProjectDescriptionStorage">
  <storageModule moduleId="org.eclipse.cdt.core.settings">
    <cconfiguration id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806">
      <storageModule buildSystemId="org.eclipse.cdt.managedbuilder.core.configurationDataProvider" id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806" moduleId="org.eclipse.cdt.core.settings" name="Debug">
        <externalSettings/>
        <extensions>
          <extension id="org.eclipse.cdt.core.ELF" point="org.eclipse.cdt.core.BinaryParser"/>
          <extension id="org.eclipse.cdt.core.GmakeErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
          <extension id="org.eclipse.cdt.core.CWDLocator" point="org.eclipse.cdt.core.ErrorParser"/>
          <extension id="org.eclipse.cdt.core.GCCErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
          <extension id="org.eclipse.cdt.core.GASErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
          <extension id="org.eclipse.cdt.core.GLDErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
        </extensions>
      </storageModule>
      <storageModule moduleId="cdtBuildSystem" version="4.0.0">
        {{if[$self->type() eq 'exe']
        <configuration artifactName="${ProjName}" buildArtefactType="org.eclipse.cdt.build.core.buildArtefactType.exe" buildProperties="org.eclipse.cdt.build.core.buildType=org.eclipse.cdt.build.core.buildType.debug,org.eclipse.cdt.build.core.buildArtefactType=org.eclipse.cdt.build.core.buildArtefactType.exe" cleanCommand="rm -rf" description="" id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806" name="Debug" parent="cdt.managedbuild.config.gnu.cross.exe.debug">
        fi}}
        {{if[$self->type() eq 'archive']
        <configuration artifactExtension="a" artifactName="${ProjName}" buildArtefactType="org.eclipse.cdt.build.core.buildArtefactType.staticLib" buildProperties="org.eclipse.cdt.build.core.buildType=org.eclipse.cdt.build.core.buildType.debug,org.eclipse.cdt.build.core.buildArtefactType=org.eclipse.cdt.build.core.buildArtefactType.staticLib" cleanCommand="rm -rf" description="" id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806" name="Debug" parent="cdt.managedbuild.config.gnu.cross.exe.debug">
        fi}}
          <folderInfo id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806." name="/" resourcePath="">
            <toolChain id="cdt.managedbuild.toolchain.gnu.cross.exe.debug.1146677503" name="Cross GCC" nonInternalBuilderId="cdt.managedbuild.builder.gnu.cross" superClass="cdt.managedbuild.toolchain.gnu.cross.exe.debug">
              <targetPlatform archList="all" binaryParser="org.eclipse.cdt.core.ELF" id="cdt.managedbuild.targetPlatform.gnu.cross.1587627046" isAbstract="false" osList="all" superClass="cdt.managedbuild.targetPlatform.gnu.cross"/>
              <builder autoBuildTarget="all" buildPath="${workspace_loc:/p1}/Debug" cleanBuildTarget="clean" id="org.eclipse.cdt.build.core.internal.builder.1935272256" incrementalBuildTarget="all" managedBuildOn="true" name="CDT Internal Builder" superClass="org.eclipse.cdt.build.core.internal.builder"/>

              <tool id="cdt.managedbuild.tool.gnu.cross.c.compiler.24600764" name="Cross GCC Compiler" superClass="cdt.managedbuild.tool.gnu.cross.c.compiler">
                <option defaultValue="gnu.c.optimization.level.none" id="gnu.c.compiler.option.optimization.level.1561788498" name="Optimization Level" superClass="gnu.c.compiler.option.optimization.level" useByScannerDiscovery="false" valueType="enumerated"/>
                <option id="gnu.c.compiler.option.debugging.level.1777737136" name="Debug Level" superClass="gnu.c.compiler.option.debugging.level" useByScannerDiscovery="false" value="gnu.c.debugging.level.max" valueType="enumerated"/>
                <inputType id="cdt.managedbuild.tool.gnu.c.compiler.input.1307460494" superClass="cdt.managedbuild.tool.gnu.c.compiler.input"/>
              </tool>
              <tool id="cdt.managedbuild.tool.gnu.cross.cpp.compiler.1114137870" name="Cross G++ Compiler" superClass="cdt.managedbuild.tool.gnu.cross.cpp.compiler">
                <option id="gnu.cpp.compiler.option.optimization.level.801299881" name="Optimization Level" superClass="gnu.cpp.compiler.option.optimization.level" useByScannerDiscovery="false" value="gnu.cpp.compiler.optimization.level.none" valueType="enumerated"/>
                <option id="gnu.cpp.compiler.option.debugging.level.174650755" name="Debug Level" superClass="gnu.cpp.compiler.option.debugging.level" useByScannerDiscovery="false" value="gnu.cpp.compiler.debugging.level.max" valueType="enumerated"/>
                <inputType id="cdt.managedbuild.tool.gnu.cpp.compiler.input.1300458405" superClass="cdt.managedbuild.tool.gnu.cpp.compiler.input"/>
              </tool>
              <tool id="cdt.managedbuild.tool.gnu.cross.c.linker.1938908928" name="Cross GCC Linker" superClass="cdt.managedbuild.tool.gnu.cross.c.linker"/>
              <tool id="cdt.managedbuild.tool.gnu.cross.cpp.linker.820171051" name="Cross G++ Linker" superClass="cdt.managedbuild.tool.gnu.cross.cpp.linker">
                <inputType id="cdt.managedbuild.tool.gnu.cpp.linker.input.914610291" superClass="cdt.managedbuild.tool.gnu.cpp.linker.input">
                  <additionalInput kind="additionalinputdependency" paths="$(USER_OBJS)"/>
                  <additionalInput kind="additionalinput" paths="$(LIBS)"/>
                </inputType>
              </tool>
              <tool id="cdt.managedbuild.tool.gnu.cross.archiver.64815811" name="Cross GCC Archiver" superClass="cdt.managedbuild.tool.gnu.cross.archiver"/>
              <tool id="cdt.managedbuild.tool.gnu.cross.assembler.578287518" name="Cross GCC Assembler" superClass="cdt.managedbuild.tool.gnu.cross.assembler">
                <inputType id="cdt.managedbuild.tool.gnu.assembler.input.2043513975" superClass="cdt.managedbuild.tool.gnu.assembler.input"/>
              </tool>
            </toolChain>
          </folderInfo>
        </configuration>
      </storageModule>
      <storageModule moduleId="org.eclipse.cdt.core.externalSettings"/>
    </cconfiguration>
  </storageModule>
  <storageModule moduleId="cdtBuildSystem" version="4.0.0">
    <project id="{{name}}.cdt.managedbuild.target.gnu.cross.exe.1360220049" name="Executable" projectType="cdt.managedbuild.target.gnu.cross.exe"/>
  </storageModule>
  <storageModule moduleId="scannerConfiguration">
    <autodiscovery enabled="true" problemReportingEnabled="true" selectedProfileId=""/>
    <scannerConfigBuildInfo instanceId="cdt.managedbuild.config.gnu.cross.exe.release.1111422221;cdt.managedbuild.config.gnu.cross.exe.release.1111422221.;cdt.managedbuild.tool.gnu.cross.cpp.compiler.1988783467;cdt.managedbuild.tool.gnu.cpp.compiler.input.1090726330">
      <autodiscovery enabled="true" problemReportingEnabled="true" selectedProfileId=""/>
    </scannerConfigBuildInfo>
    <scannerConfigBuildInfo instanceId="cdt.managedbuild.config.gnu.cross.exe.release.1111422221;cdt.managedbuild.config.gnu.cross.exe.release.1111422221.;cdt.managedbuild.tool.gnu.cross.c.compiler.777061988;cdt.managedbuild.tool.gnu.c.compiler.input.1863796140">
      <autodiscovery enabled="true" problemReportingEnabled="true" selectedProfileId=""/>
    </scannerConfigBuildInfo>
    <scannerConfigBuildInfo instanceId="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806;cdt.managedbuild.config.gnu.cross.exe.debug.1121008806.;cdt.managedbuild.tool.gnu.cross.c.compiler.24600764;cdt.managedbuild.tool.gnu.c.compiler.input.1307460494">
      <autodiscovery enabled="true" problemReportingEnabled="true" selectedProfileId=""/>
    </scannerConfigBuildInfo>
    <scannerConfigBuildInfo instanceId="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806;cdt.managedbuild.config.gnu.cross.exe.debug.1121008806.;cdt.managedbuild.tool.gnu.cross.cpp.compiler.1114137870;cdt.managedbuild.tool.gnu.cpp.compiler.input.1300458405">
      <autodiscovery enabled="true" problemReportingEnabled="true" selectedProfileId=""/>
    </scannerConfigBuildInfo>
  </storageModule>
  <storageModule moduleId="org.eclipse.cdt.core.LanguageSettingsProviders"/>
</cproject>
CEOF

sub type {
    #print("in type()\n");
    my ($self) = @_;
    return $$self{'type'} || 'archive';
}

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    $$self{'fname'} = '.cproject';
    return $self;
}
sub getRaw { return $c; }

package makefile_rule;
@ISA = ('template','geneclipse');

$c=<<'MAKEFILERULE';
{{target}} : {{dependencies}}
{{rules}}
MAKEFILERULE

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    map { my $r = $_; $$r{'_up'} = [grep { defined($_) } ($$r{'_up'},$self)] } @{$$self{'rules'}};
    return $self;
}
sub getRaw { return $c; }

sub setProjectPath {
  my ($self,$p) = @_; my $cnt;
  $$self{'target'} = $$self{'_target'};
  if (!($$self{'_target'} =~ /^all$/ || $$self{'_target'} =~ /^clean$/)) {
    my $o = $$self{'target'};
    $$self{'target'} = File::Spec->abs2rel(File::Spec->rel2abs($$self{'_target'}),File::Spec->rel2abs($p));
    print ("trans:".$o."(base:$p) => ".$$self{'target'}."\n") if ($::OPT{dbgtrans});
  }
  $$self{'dependencies'} = 
    join(" ", map { 
      my $o = $_;
      my $n = File::Spec->abs2rel(File::Spec->rel2abs($_),File::Spec->rel2abs($p));
      print ("trans:".$o."(base:$p) => ".$n."\n") if ($::OPT{dbgtrans});
      $n
    } (@{$$self{'_rulesdep'}}));
}

package makefile;
@ISA = ('template','geneclipse');
use Data::Dumper;
use File::Basename;

$c=<<'MAKEFILE';
{{call[($$self{'dos'} ? $self->convDos($m) : $self->convPosix($m))]
{{makeinc}}
# parts:
{{parts}}
llac}}
MAKEFILE

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    $$self{'fname'} = 'Makefile.{{os.make.ext}}.mk';
    $$self{'parts'} = [] if (!exists($$self{'parts'}));
    $$self{'makeinc'} = [] if (!exists($$self{'makeinc'}));
    return $self;
}

sub addPart {
    my ($self,$r) = @_;
    push(@{$$self{'parts'}},$r);
    $$r{'_up'} = [grep { defined($_) } (($$r{'_up'}),$self)];
}

sub getRaw { return $c; }

sub subTemplate {
  my ($self) = @_;
  my $p = ".";
  $p = $$self{'pdir'} if defined($$self{'pdir'});
  foreach my $r (@{$$self{'parts'}}) {
      $r->setProjectPath($p);
  }
  $self->template::subTemplate();
}

sub saveTo {
  my ($self) = shift;
  my @o = grep { geneclipse::hasos( $$_{'os'}) } 
    ({'os.make.ext'=>'gmake','os'=>'cygwin'},
     {'os.make.ext'=>'nmake','os'=>'com'} );
  foreach my $os (@o) {
    my $n = $$os{'n'};
    my $o = $$os{'os'};
    my $def = $$osenv::os{$o};
    $self->appendTail($def);
    
    # create include fine and include it
    $g_ = $self->getValue('genflags');
    if (ref($g_) eq ref []) {
      my @l = @{$$self{'makeinc'}};
      for my $g (@$g_) {
      	my ($fn,$a,$g) = @{$g};
	$fn = $self->doSub($fn);
	$self->genFlagsFile($fn,$a,$g);
	push(@{$$self{'makeinc'}},new textsnipppet({'_up'=>$self},"{{os.make.inc}} {{file${fn}elif}}\n"));
      }
      $self{'makeinc'} = [@l];
    }
    $self->geneclipse::saveTo();
    if ($o eq 'cygwin') {
      my $of = $self->getFilename(@_);
my $p=<<"CMD";
#!/bin/sh
{{filebuild/nocyg.batelif}} {{{{PERLMAKE}}call}} $of
CMD
      my $c = new textsnipppet({'_up'=>$self,'pdir'=>$$self{'pdir'},'fname'=>(basename($of).".sh")},$p);
      $c->saveTo();
    }
    
    $self->remove($def);
  }
  
my $p=<<"CMD";
include Makefile.gmake.mk
CMD
  if (! -f $$self{'pdir'}."/Makefile") {
    my $c = new textsnipppet({'_up'=>$self,'pdir'=>$$self{'pdir'},'fname'=>'Makefile'},$p);
    $c->saveTo();
  }  
}

package osenv;
@ISA = ('template','geneclipse');

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    return $self;
}

$gmake = new osenv(
   {'os.make.ext'=>'gmake',
    'os.make.inc'=>'include',
    '$<' => '$<',
    '$^' => '$^'
   }
);
$oswin_cygwin = new osenv(
   {'_up'=>$gmake, 
    'PERLMAKE' => 'dmake',
    'makecall'  => 'make -f', 
    'dmakecall' => 'dmake -f', 'nmakecall' => 'nmake /f '}
);
$oswin_com    = new osenv(
   {'os.make.ext'=>'nmake',
    'os.make.inc'=>'!include',
    '$<' => '$**',
    '$^' => '$**'}
);
$oslinux_com  = new osenv({'_up'=>$gmake});
$osmac_com    = new osenv({'_up'=>$gmake});
$os = {
  'cygwin'    => $oswin_cygwin,
  'com'       => $oswin_com,
  'linux'     => $oslinux_com,
  'mac'       => $osmac_com
};

package genenv;
@ISA = ('template','geneclipse');
use File::Temp qw/tempfile/;

$c=<<'ENV';
ENV

sub exePerl {
    my ($e) = @_;
    my ($fh, $filename) = tempfile();
    print $fh "$e";
    close($fh);
    return `perl $filename`;
}

sub new {
    my ($class,$self) = @_;
    bless $self, $class;
    $$self{'PERL'} = "perl";
    $$self{'PERLLIB'} = exePerl("use Config; foreach \$l ('installprivlib', 'archlibexp') { if (-f \$Config{\$l}.'/ExtUtils/xsubpp') { print \$Config{\$l}; last; }}");
    $$self{'PERLMAKE'} = exePerl('use Config; print $Config{make};');
    $$self{'COPY'} = ($::defos =~ /win/ ) ?  'copy /Y' : 'cp';
    foreach my $m ('PERLLIB','PERLMAKE') {
	$$self{$m} =~ s/\n$//;
    } 
    return $self;
}

sub getRaw { return $c; }

sub subTemplate {
  my ($self) = @_;
  my $p = ".";
  $self->template::subTemplate();
}

1;
