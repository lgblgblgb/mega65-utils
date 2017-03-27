SJASM		= sjasm
ALL_DEPENDS	= Makefile
CPM_UTILS	= cpmver.asm
BINARIES	= $(CPM_UTILS:.asm=.com)

all: $(BINARIES)

%.com: %.asm $(ALL_DEPENDS)
	$(SJASM) -s $< $@ || { rm -f $@ $(@:.com=.lst) $(@:.com=.sym) ; false; }


clean:
	$(RM) -f *.sym *.lst $(BINARIES)


.PHONY: all clean
