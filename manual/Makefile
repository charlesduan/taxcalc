TEXCMD = xelatex

main: taxcalc.pdf
%.pdf: %.tex FORCE
	base="`basename "$<" .tex`"; \
	touch "$$base".aux; \
	for i in 1 2 3 4 ; do \
	    oldsum="`shasum "$$base".aux`"; \
	    $(TEXCMD) "$<" || exit 1; \
	    newsum="`shasum "$$base".aux`"; \
	    if [ "$$newsum" = "$$oldsum" ] ; then \
		break; \
	    fi \
	done

FORCE:

clean:
	rm -f *.log *.aux *.toc *.dvi *.toa *.snm *.nav *.out
	rm -f *.4ct *.4tc *.idv *.lg *.tmp *.xdv *.xref
	rm -f out.pdf cover.pdf body.pdf

