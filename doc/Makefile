DOC := ieee754_float_ug
TEX := $(wildcard *.tex) fpug.cls $(wildcard figures/*)

all: $(DOC).pdf

$(DOC).pdf: $(TEX)
	latexmk -pdf -interaction=nonstopmode -halt-on-error -jobname=$(DOC) ug.tex

clean:
	latexmk -c -jobname=$(DOC) ug.tex

.PHONY: all clean
