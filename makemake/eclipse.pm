######################################################################
# .project 

package makemake::eclipse_project;
@ISA = ('makemake::template','makemake::node');

$ptxt=<<'PEOF';
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
  <name>{{id}}</name>
  <comment></comment>
	<projects>
{{depprojects}}	
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
  {{['c'=>'etxt']get:linkedResources}}
  </linkedResources>
  <filteredResources>
		<filter>
			<id>1403448937531</id>
			<name>out</name>
			<type>5</type>
			<matcher>
				<id>org.eclipse.ui.ide.multiFilter</id>
				<arguments>1.0-name-matches-false-false-*</arguments>
			</matcher>
		</filter>
  </filteredResources>
</projectDescription>
PEOF

my $idx = 0;

sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_project$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'txt'=>$ptxt};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
	$$s{'linkedResources'} = [ grep { defined($_) } @{$$s{'linkedResources'}} ];
    makemake::graph::putNode($g,$n,$s);
    return $s;
}

package makemake::eclipse_project::folder;
@ISA = ('makemake::template','makemake::node');
use File::Basename;
use File::Path;

$eres=<<'FEOF';
<link>
	<name>{{dir}}</name>
	<type>2</type>
	<locationURI>{{get:self.releprojectfname}}</locationURI>
</link>
FEOF

sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_project_resource$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'etxt'=>$eres,'_fname'=>'virtual:/virtual', 'pdir'=>'virtual:/virtual'};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
    makemake::graph::putNode($g,$n,$s);
 	makemake::addOptEdge($g,$n,$s);
	return $s;
}



######################################################################
# .cproject nature

package makemake::eclipse_cproject;
@ISA = ('makemake::template','makemake::node','makemake::eclipse_cproject::options_funcs');

$ctxt=<<'CEOF';
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?fileVersion 4.0.0?><cproject storage_type_id="org.eclipse.cdt.core.XmlProjectDescriptionStorage">
	<storageModule moduleId="org.eclipse.cdt.core.settings">
		<cconfiguration id="{{cdt.rel.id}}">
			<storageModule buildSystemId="org.eclipse.cdt.managedbuilder.core.configurationDataProvider" id="{{cdt.rel.id}}" moduleId="org.eclipse.cdt.core.settings" name="mybuild">
				<externalSettings/>
				<extensions>
					<extension id="org.eclipse.cdt.core.GCCErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
					<extension id="org.eclipse.cdt.core.GASErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
					<extension id="org.eclipse.cdt.core.GLDErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
{{if[!$$s{'eclipseinternal'}]
					<extension id="org.eclipse.cdt.core.GmakeErrorParser" point="org.eclipse.cdt.core.ErrorParser"/>
					<extension id="org.eclipse.cdt.core.CWDLocator" point="org.eclipse.cdt.core.ErrorParser"/>
fi}}
					<extension id="org.eclipse.cdt.core.ELF" point="org.eclipse.cdt.core.BinaryParser"/>
				</extensions>
			</storageModule>
			<storageModule moduleId="cdtBuildSystem" version="4.0.0">


        {{if[$$s{'ext'} eq 'a']
				<configuration artifactName="${ProjName}" buildArtefactType="org.eclipse.cdt.build.core.buildArtefactType.exe" buildProperties="org.eclipse.cdt.build.core.buildType=org.eclipse.cdt.build.core.buildType.release,org.eclipse.cdt.build.core.buildArtefactType=org.eclipse.cdt.build.core.buildArtefactType.exe" cleanCommand="rm -rf" description="" id="{{cdt.rel.id}}" name="mybuild" parent="cdt.managedbuild.config.gnu.cross.exe.release">
	    fi}}
        {{if[$$s{'ext'} eq 'exe']
				<configuration artifactName="${ProjName}" buildArtefactType="org.eclipse.cdt.build.core.buildArtefactType.exe" buildProperties="org.eclipse.cdt.build.core.buildType=org.eclipse.cdt.build.core.buildType.release,org.eclipse.cdt.build.core.buildArtefactType=org.eclipse.cdt.build.core.buildArtefactType.exe" cleanCommand="rm -rf" description="" id="{{cdt.rel.id}}" name="mybuild" parent="cdt.managedbuild.config.gnu.cross.exe.release">
	    fi}}


					<folderInfo id="{{cdt.rel.id}}." name="/" resourcePath="">
						<toolChain id="cdt.managedbuild.toolchain.gnu.cross.exe.release.641888188" name="Cross GCC" nonInternalBuilderId="cdt.managedbuild.builder.gnu.cross" superClass="cdt.managedbuild.toolchain.gnu.cross.exe.release">
							<targetPlatform archList="all" binaryParser="org.eclipse.cdt.core.ELF" id="cdt.managedbuild.targetPlatform.gnu.cross.1429186970" isAbstract="false" osList="all" superClass="cdt.managedbuild.targetPlatform.gnu.cross"/>
{{if[!$$s{'eclipseinternal'}]
	                        <!-- External build, use Makefile in project directory -->
							<builder buildPath="${workspace_loc:/{{id}}}/" id="cdt.managedbuild.builder.gnu.cross.2131548152" keepEnvironmentInBuildfile="false" managedBuildOn="false" name="Gnu Make Builder" superClass="cdt.managedbuild.builder.gnu.cross"/>
fi}}
{{if[$$s{'eclipseinternal'}]
	                        <!-- Internal build, use internal builder, use subdir /build -->
							<builder autoBuildTarget="all" buildPath="${workspace_loc:/{{id}}}/build" cleanBuildTarget="clean" id="org.eclipse.cdt.build.core.internal.builder.823320385" incrementalBuildTarget="all" managedBuildOn="true" name="CDT Internal Builder" superClass="org.eclipse.cdt.build.core.internal.builder"/>
fi}}
							<tool id="{{cdt.gcc.id}}" name="Cross GCC Compiler" superClass="cdt.managedbuild.tool.gnu.cross.c.compiler">
								<option defaultValue="gnu.c.optimization.level.most" id="gnu.c.compiler.option.optimization.level.1706717527" name="Optimization Level" superClass="gnu.c.compiler.option.optimization.level" useByScannerDiscovery="false" valueType="enumerated"/>
								<option id="gnu.c.compiler.option.debugging.level.313044254" name="Debug Level" superClass="gnu.c.compiler.option.debugging.level" useByScannerDiscovery="false" value="gnu.c.debugging.level.none" valueType="enumerated"/>

                                {{if[$s->hassymoptions]
							         <option id="gnu.c.compiler.option.preprocessor.def.symbols.{{gidx0}}" superClass="gnu.c.compiler.option.preprocessor.def.symbols" valueType="definedSymbols">
   						             {{symoptions}}
						         	 </option>
				                fi}}
                                {{if[$s->hasincoptions]
							         <option id="gnu.c.compiler.option.include.paths.{{gidx0}}" superClass="gnu.c.compiler.option.include.paths" valueType="includePath">
								     {{incoptions}}
							         </option>
				                fi}}



								<inputType id="cdt.managedbuild.tool.gnu.c.compiler.input.1509244468" superClass="cdt.managedbuild.tool.gnu.c.compiler.input"/>
							</tool>
							<tool id="cdt.managedbuild.tool.gnu.cross.cpp.compiler.1466514914" name="Cross G++ Compiler" superClass="cdt.managedbuild.tool.gnu.cross.cpp.compiler">
								<option id="gnu.cpp.compiler.option.optimization.level.509641899" name="Optimization Level" superClass="gnu.cpp.compiler.option.optimization.level" useByScannerDiscovery="false" value="gnu.cpp.compiler.optimization.level.most" valueType="enumerated"/>
								<option id="gnu.cpp.compiler.option.debugging.level.1529909255" name="Debug Level" superClass="gnu.cpp.compiler.option.debugging.level" useByScannerDiscovery="false" value="gnu.cpp.compiler.debugging.level.none" valueType="enumerated"/>

                                {{if[$s->hassymoptions]
								     <option id="gnu.cpp.compiler.option.preprocessor.def.{{gidx0}}" superClass="gnu.cpp.compiler.option.preprocessor.def" valueType="definedSymbols">
   						             {{symoptions}}
						         	 </option>
				                fi}}
                                {{if[$s->hasincoptions]
							         <option id="gnu.cpp.compiler.option.include.paths.{{gidx0}}" superClass="gnu.cpp.compiler.option.include.paths" valueType="includePath">
								     {{incoptions}}
							         </option>
				                fi}}

								<inputType id="cdt.managedbuild.tool.gnu.cpp.compiler.input.997568568" superClass="cdt.managedbuild.tool.gnu.cpp.compiler.input"/>
							</tool>
							<tool id="cdt.managedbuild.tool.gnu.cross.c.linker.968692083" name="Cross GCC Linker" superClass="cdt.managedbuild.tool.gnu.cross.c.linker"/>
							<tool id="cdt.managedbuild.tool.gnu.cross.cpp.linker.1620120599" name="Cross G++ Linker" superClass="cdt.managedbuild.tool.gnu.cross.cpp.linker">
								<inputType id="cdt.managedbuild.tool.gnu.cpp.linker.input.1300613097" superClass="cdt.managedbuild.tool.gnu.cpp.linker.input">
									<additionalInput kind="additionalinputdependency" paths="$(USER_OBJS)"/>
									<additionalInput kind="additionalinput" paths="$(LIBS)"/>
								</inputType>
							</tool>
							<tool id="cdt.managedbuild.tool.gnu.cross.archiver.826243478" name="Cross GCC Archiver" superClass="cdt.managedbuild.tool.gnu.cross.archiver"/>
							<tool id="cdt.managedbuild.tool.gnu.cross.assembler.442367923" name="Cross GCC Assembler" superClass="cdt.managedbuild.tool.gnu.cross.assembler">
								<inputType id="cdt.managedbuild.tool.gnu.assembler.input.452177813" superClass="cdt.managedbuild.tool.gnu.assembler.input"/>
							</tool>
						</toolChain>
					</folderInfo>
                    {{perfileoptions}}
				</configuration>
			</storageModule>
			<storageModule moduleId="org.eclipse.cdt.core.externalSettings"/>
		</cconfiguration>
	</storageModule>
	<storageModule moduleId="cdtBuildSystem" version="4.0.0">
		<project id="{{id}}.cdt.managedbuild.target.gnu.cross.exe.1360220049" name="Executable" projectType="cdt.managedbuild.target.gnu.cross.exe"/>
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
	<storageModule moduleId="refreshScope" versionNumber="2">
		<configuration configurationName="mybuild"/>
		<configuration configurationName="Debug">
			<resource resourceType="PROJECT" workspacePath="/{{id}}"/>
		</configuration>
		<configuration configurationName="build">
			<resource resourceType="PROJECT" workspacePath="/{{id}}"/>
		</configuration>
	</storageModule>
</cproject>

CEOF

$idx = 0; $gid = 1140740847;
sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_cproject$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'txt'=>$ctxt,'perfileoptions'=>[],
			 'cdt.rel.id' => 'cdt.managedbuild.config.gnu.cross.exe.release.143346477',
			 'cdt.gcc.id' => 'cdt.managedbuild.tool.gnu.cross.c.compiler.548568518',
			 'gidx0'=> $gid++,
			 'symoptions'=>[], 'incoptions'=>[]
	};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
	$$s{'eclipseinternal'} = $::OPT{'eclipse-internal'};
    makemake::graph::putNode($g,$n,$s);
	makemake::addOptEdge($g,$n,$s);
    return $s;
}

#sub hasoptions    { my ($s) = @_; return $s->hasincoptions && $s->hassymoptions; }
#sub hasincoptions { my ($s) = @_; return (scalar(@{$$s{'incoptions'}})); }
#sub hassymoptions { my ($s) = @_; return (scalar(@{$$s{'symoptions'}})); }

sub pushOption { my ($s,$g,$n,$o) = @_; makemake::graph::addVarEdge($g,$n,$s,$o); push(@{$$s{'perfileoptions'}},$o); }

package makemake::eclipse_cproject::options;
@ISA = ('makemake::template','makemake::node','makemake::eclipse_cproject::options_funcs');

$ctxt=<<'CTOOLEOF';

                <fileInfo id="{{cdt.rel.id}}.{{gidx0}}" name="{{fname}}" rcbsApplicability="disable" resourcePath="{{fname}}" toolsToInvoke="{{cdt.gcc.id}}.{{gidx0}}">
						<tool id="{{cdt.gcc.id}}.{{gidx0}}" name="Cross GCC Compiler" superClass="{{cdt.gcc.id}}">
                {{if[$s->hassymoptions]
							<option id="gnu.c.compiler.option.preprocessor.def.symbols.{{gidx0}}" superClass="gnu.c.compiler.option.preprocessor.def.symbols" valueType="definedSymbols">
   						        {{symoptions}}
							</option>
				fi}}
                {{if[$s->hasincoptions]
							<option id="gnu.c.compiler.option.include.paths.{{gidx0}}" superClass="gnu.c.compiler.option.include.paths" valueType="includePath">
								{{incoptions}}
							</option>
				fi}}
							<inputType id="cdt.managedbuild.tool.gnu.c.compiler.input.{{gidx0}}" superClass="cdt.managedbuild.tool.gnu.c.compiler.input"/>
						</tool>
				</fileInfo>
CTOOLEOF

$idx = 0;
sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_cproject_options_tool$idx"; $idx++;
    my $s = {
		'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'txt'=>$ctxt,
		'symoptions'=>[], 'incoptions'=>[]
	};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
    makemake::graph::putNode($g,$n,$s);
    return $s;
}

package makemake::eclipse_cproject::options_funcs;

sub hasoptions    { my ($s) = @_; return $s->hasincoptions && $s->hassymoptions; }
sub hasincoptions { my ($s) = @_; return (scalar(@{$$s{'incoptions'}})); }
sub hassymoptions { my ($s) = @_; return (scalar(@{$$s{'symoptions'}})); }

sub subquote {
	my ($m) = @_;
	$m =~ s/"([^"]+)"/'"$1"'/g; # "texvalue" => '"texvalue"'
	$m =~ s/"/&quot;/g;
	return $m;
}

sub pushdefine { 
	my ($s,$v) = @_; 
	print(" ++ pushdefine: $v\n") if ($::OPT{'verbose'});
	$v = subquote($v);
	push(@{$$s{'symoptions'}}, "<listOptionValue builtIn=\"false\" value=\"$v\"/>");
}

sub pushinc { 
	my ($s,$v) = @_; 
	print(" ++ pushinc: $v\n")  if ($::OPT{'verbose'});
	$v = subquote($v);
	push(@{$$s{'incoptions'}}, "<listOptionValue builtIn=\"false\" value=\"$v\"/>");
}

1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
