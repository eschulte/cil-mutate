SOURCES = cilMutate.ml
MODULES = $(SOURCES:.ml=.cmx)
EXES = $(MODULES:.cmx=)

OCAML_OPTIONS = -I $(shell ocamlfind query cil)
OCAMLC = ocamlc -g $(OCAML_OPTIONS)
OCAMLOPT = ocamlopt -w Aelzv $(OCAML_OPTIONS)
OCAMLLIBS = \
	str.cmxa \
	unix.cmxa \
	nums.cmxa

all: cil-mutate
.PHONY: clean install

%.cmx: %.ml
	$(OCAMLOPT) -o $@ -c $*.ml

%: %.cmx
	$(OCAMLOPT) -o $@ $(OCAMLLIBS) cil.cmxa $^

cil-mutate: cilMutate
	mv $< $@

clean:
	rm -f $(EXES) $(MODULES) *.cmi *.cmo *.o cil-mutate

install: cil-mutate
	mkdir -p $(DESTDIR)/bin
	install -D $< $(DESTDIR)/bin
