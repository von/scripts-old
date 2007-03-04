######################################################################
#
# Makefile for scripts
#
######################################################################

INSTALL_DIR=$(HOME)/scripts

######################################################################

INSTALL=install
INSTALL_EXEC=$(INSTALL) -m 755
INSTALL_FILE=$(INSTALL) -m 644

MKDIR=mkdir -p

######################################################################

default: 
	@echo "Use 'make install' to install."
	@echo "Install directory is $(INSTALL_DIR)"

######################################################################

install:: install_dir

install_dir: $(INSTALL_DIR)

$(INSTALL_DIR):
	$(MKDIR) $@

######################################################################

# Replace Makefile.inc with Makefile.tmp only if it is different
Makefile.inc: Makefile.tmp
	@if test -f $@ ; then diff $^ $@ || mv $^ $@ ; else mv $& $@ ; fi
	@rm -f $^

Makefile.tmp:
	@echo "" > $@
	@for ext in .py .pl .sh ; do \
		for script in `find . -name \*$${ext}`; do \
			echo "$${script}" 1>&2 ;\
			basename=`basename -s $${ext} $${script}` ;\
			target="\$$(INSTALL_DIR)/$${basename}" ;\
			echo "" ;\
			echo "install :: $${basename}-install" ;\
			echo "" ;\
			echo "$${basename}-install: $${target}" ;\
			echo "" ;\
			echo "$${target}: install_dir" ;\
			echo "	\$$(INSTALL_EXEC) $${script} \$$@" ;\
			echo "" ;\
		done ;\
	done > $@

######################################################################

include Makefile.inc

######################################################################
