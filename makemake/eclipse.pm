######################################################################
# .project 

package makemake::eclipse_project;
@ISA = ('makemake::template','makemake::node');

$ptxt=<<'PEOF';
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
  <name>test{{id}}</name>
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
  {{['c'=>'etxt']get:linkedResources}}
  </linkedResources>
</projectDescription>
PEOF

my $idx = 0;

sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_project$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'txt'=>$ptxt};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
    makemake::graph::putNode($g,$n,$s);
    return $s;
}

package makemake::eclipse_project::vfolder;
@ISA = ('makemake::template','makemake::node');
use File::Basename;
use File::Path;

$eres=<<'FEOF';
<link>
	<name>{{dir}}</name>
	<type>2</type>
	<locationURI>virtual:/virtual</locationURI>
</link>
FEOF

sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_project_resource$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'etxt'=>$eres};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
    makemake::graph::putNode($g,$n,$s);
    return $s;
}



######################################################################
# .cproject nature

package makemake::eclipse_cproject;
@ISA = ('makemake::template','makemake::node');

$ctxt=<<'CEOF';
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
        {{if[$$s{'ext'} eq 'exe']
        <configuration artifactName="${ProjName}" buildArtefactType="org.eclipse.cdt.build.core.buildArtefactType.exe" buildProperties="org.eclipse.cdt.build.core.buildType=org.eclipse.cdt.build.core.buildType.debug,org.eclipse.cdt.build.core.buildArtefactType=org.eclipse.cdt.build.core.buildArtefactType.exe" cleanCommand="rm -rf" description="" id="cdt.managedbuild.config.gnu.cross.exe.debug.1121008806" name="Debug" parent="cdt.managedbuild.config.gnu.cross.exe.debug">
        fi}}
        {{if[$$s{'ext'} eq 'a']
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
</cproject>
CEOF

sub new {
    my ($c,$g,$n,$s_) = @_;
    my $name = "_eclipse_cproject$idx"; $idx++;
    my $s = {'_g'=>$g,'_n'=>$n,'_id'=>$name,'_name'=>$name,'txt'=>$ctxt};
    bless $s,$c;
    $s->merge($s_) if (defined($s_));;
    makemake::graph::putNode($g,$n,$s);
    return $s;
}


1;

# Local Variables:
# tab-width: 4
# cperl-indent-level: 4
# End:
