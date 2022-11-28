FILENAME = main

date = $(shell date +%Y-%m-%d)
output_file = draft_$(date).pdf

# lualatex is having a problem with minted
LATEX = pdf #pdflatex
# LATEX = xelatex
# LATEX = lualatex

# BIBTEX = bibtex
BIBTEX = biber

default: text copy_draft

all: default

text:
	latexmk -$(LATEX) -logfilewarnings -halt-on-error -shell-escape $(FILENAME)

copy_draft:
	rsync $(FILENAME).pdf $(output_file)
	rsync $(FILENAME).pdf ichep_2022_proceedings.pdf

clean:
	rm -f *.aux *.bbl *.blg *.dvi *.idx *.lof *.log *.lot *.toc \
		*.xdy *.nav *.out *.snm *.vrb *.mp \
		*.synctex.gz *.brf *.fls *.fdb_latexmk \
		*.glg *.gls *.glo *.ist *.alg *.acr *.acn *.pyg

clean_drafts:
	rm -f draft_*.pdf

realclean: clean clean_drafts
	rm -f $(FILENAME).pdf ichep_2022_proceedings.pdf
	rm -rf _minted-$(FILENAME)

lint:
	grep -E --color=always -r -i --include=\*.tex --include=\*.bib "(\b[a-zA-Z]+) \1\b" || true

final:
	if [ -f *.aux ]; then \
		$(MAKE) clean; \
	fi
	$(MAKE) abstract
	$(MAKE) text
	$(MAKE) clean
	$(MAKE) lint

arXiv: deep_clean text
	# Get a minted cache
	sed -i.bak 's/cache=false/cache=true/' latex/packages.tex
	$(MAKE) text

	mkdir submit_to_arXiv
	cp $(FILENAME).tex submit_to_arXiv
	if [ -f $(FILENAME).bbl ]; then cp $(FILENAME).bbl submit_to_arXiv/ms.bbl; fi
	cp Makefile submit_to_arXiv

	if [ -d src ]; then cp -r src submit_to_arXiv; fi
	if [ -d latex ]; then cp -r latex submit_to_arXiv; fi
	if [ -d figures ]; then cp -r figures submit_to_arXiv; fi
	if [ -f *.sty ]; then cp *.sty submit_to_arXiv; fi
	# .bst files are not used, but copy over to inlcude all src files for posterity
	if [ -f *.bst ]; then cp *.bst submit_to_arXiv; fi
	# PoS specific files
	cp pos.sty PoSlogo.pdf PoSlogo.ps submit_to_arXiv
	# https://arxiv.org/help/00README
	if [ -f 00README.XXX ]; then cp 00README.XXX submit_to_arXiv; fi

	# Use cache for minted
	# c.f. https://github.com/gpoore/minted/issues/113#issuecomment-223451550
	mv _minted-$(FILENAME) submit_to_arXiv/_minted-ms
	sed -i.bak 's/finalizecache/frozencache/' submit_to_arXiv/latex/packages.tex
	# https://tex.stackexchange.com/questions/661171/package-minted-error-missing-style-definition-for-with-frozencache-when-submitt
	curl -sL https://raw.githubusercontent.com/gpoore/minted/v2.6/source/minted.sty -o submit_to_arXiv/minted.sty

	mv submit_to_arXiv/$(FILENAME).tex submit_to_arXiv/ms.tex

	# -i.bak is used for compatability across GNU and BSD/macOS sed
	# Change the FILENAME to ms while ignoring commented lines
	sed -i.bak '/^ *#/d;s/#.*//;0,/FILENAME/s/.*/FILENAME = ms/' submit_to_arXiv/Makefile

	# Remove hyperref for arXiv
	# N.B. Need to manually set the file to edit for the time being
	# N.B. Currently fixed by 00README.XXX

	find submit_to_arXiv/ -name "*.bak" -type f -delete

	# arXiv requires .bib files to be compiled to .bbl files and will remove any .bib files
	find submit_to_arXiv/ -name "*.bib" -type f -delete

	tar -zcvf submit_to_arXiv.tar.gz submit_to_arXiv/
	rm -rf submit_to_arXiv
	$(MAKE) realclean

	# Restore original packages
	if [ -f latex/packages.tex.bak ];then \
		mv latex/packages.tex.bak latex/packages.tex; \
	fi

list_arXiv:
	tar -tvf submit_to_arXiv.tar.gz

test_arXiv:
	tar -xzvf submit_to_arXiv.tar.gz
	cd submit_to_arXiv && make

clean_arXiv:
	if [ -f submit_to_arXiv.tar.gz ];then \
		rm submit_to_arXiv.tar.gz; \
	fi

deep_clean: realclean clean_arXiv
	rm -rf submit_to_arXiv
