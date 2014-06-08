
# include files
include Makefile.e.flags.gmake.mk
# parts:
# rule "all"
all : out/e.a out/libe.a out/libgtest.a out/test1.exe

###############################
# out/libe.a
# rule "out/libe.a"
out/libe.a : out/tok.o out/parse.o
	ar cr out/libe.a out/tok.o out/parse.o ; ranlib out/libe.a 
# rule "out/tok.o"
out/tok.o : tok.c
	gcc -c -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   tok.c  -o out/tok.o 
# rule "out/parse.o"
out/parse.o : parse.c
	gcc -c -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   parse.c  -o out/parse.o 
###############################
# out/e.a
# rule "out/e.a"
out/e.a : out/e.o
	ar cr out/e.a out/e.o ; ranlib out/e.a 
# rule "out/e.o"
out/e.o : e.c
	gcc -c -Iperl -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   e.c  -o out/e.o 
# rule "e.c"
e.c : perl/e.xs
	perl /Users/eiselekd/bin/lib/perl5/5.18.0/ExtUtils/xsubpp -typemap /Users/eiselekd/bin/lib/perl5/5.18.0/ExtUtils/typemap -typemap typemap ../perl/e.xs -output $@
###############################
# out/libgtest.a
# rule "out/libgtest.a"
out/libgtest.a : out/gtest-all.o
	ar cr out/libgtest.a out/gtest-all.o ; ranlib out/libgtest.a 
# rule "out/gtest-all.o"
out/gtest-all.o : perl/tmp-gtest/gtest-1.7.0/src/gtest-all.cc
	g++ -c -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   perl/tmp-gtest/gtest-1.7.0/src/gtest-all.cc  -o out/gtest-all.o 
###############################
# out/test1.exe
# rule "out/test1.exe"
out/test1.exe : out/test1.o out/gtest_main.o out/e.a out/libgtest.a out/libe.a
	g++ out/test1.o out/gtest_main.o out/e.a out/libgtest.a out/libe.a  $(PERL_LDOPTS)  -o out/test1.exe 
# rule "out/test1.o"
out/test1.o : perl/t/test1.cpp
	g++ -c -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   perl/t/test1.cpp  -o out/test1.o 
# rule "out/gtest_main.o"
out/gtest_main.o : perl/tmp-gtest/gtest-1.7.0/src/gtest_main.cc
	g++ -c -Iperl/tmp-gtest/gtest-1.7.0/include -Iperl/tmp-gtest/gtest-1.7.0  $(PERL_CCOPTS) $(CFLAGS)   perl/tmp-gtest/gtest-1.7.0/src/gtest_main.cc  -o out/gtest_main.o 
###############################
# all
# rule "e.a"
e.a : out/e.a

# rule "libe.a"
libe.a : out/libe.a

# rule "libgtest.a"
libgtest.a : out/libgtest.a

# rule "test1.exe"
test1.exe : out/test1.exe

# rule "clean_alias_0"
clean : 
	rm -rf out/e.a out/e.o out/libe.a out/tok.o out/parse.o out/libgtest.a out/gtest-all.o out/test1.exe out/test1.o out/gtest_main.o
# rule ".PHONY_alias_1"
.PHONY : e.a libe.a libgtest.a test1.exe



-include Makefile.inc.mk

