SOURCES = cilMutate.ml
OBJECTS = $(SOURCES:.ml=.cmx)

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

cil-mutate: $(OBJECTS)
	$(OCAMLOPT) -o $@ $(OCAMLLIBS) cil.cmxa $(OBJECTS)

clean:
	rm -f cil-mutate $(OBJECTS) *.cmi *.cmo *.o

install: cil-mutate
	mkdir -p $(DESTDIR)/bin
	install -D $< $(DESTDIR)/bin
