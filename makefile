PROJECTNAME := FCDEMO

FILENAME = demo
DATE = $(shell date +%Y%m%d)
ARCHIVEFILENAME = $(PROJECTNAME)_$(DATE)

DEPPATH = dep
BINPATH = bin
DEBUGPATH = .
OBJPATH = obj
SRCPATH = .
LIBPATH = lib
ARCHIVEPATH = .
AS = ./vasmm68k_mot
VLINK = ./vlink

vpath %.s $(SRCPATH)
vpath %.o $(OBJPATH)

$(FILENAME) : main.s
	$(AS) -m68000 -kick1hunks -Fhunkexe -o $@ $<

.PHONY: run $(FILENAME)
run: 
	fs-uae ./demo.fs-uae
