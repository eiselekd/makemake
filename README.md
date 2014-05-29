makemake
========

Generate Makefile and eclipse projects files from simple description. 

Rationale
=========
Generate gmake and nmake Makefiles and eclipse .project and .cproject files from
a simple description file. Then be able to use headless eclipse's build to build
and unittest: 

```bash
	D:\\eclipse\\eclipse.exe -nosplash \
	-application org.eclipse.cdt.managedbuilder.core.headlessbuild  \
	-data c:\\temp\\workspacedirectory \
        -import tmp\\e.a \
        -build p1/Debug \
        -cleanBuild p1/Debug \
```
