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

realclean: clean
	rm -f *.ps *.pdf

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
	sed -i.bak 's/cache=false/cache=true/' $(FILENAME).tex
	$(MAKE) text
	# Copy files
	mkdir submit_to_arXiv
	cp $(FILENAME).tex submit_to_arXiv
	cp *.bbl submit_to_arXiv/ms.bbl
	# .bst files are not used, but copy over to inlcude all src files for posterity
	cp *.bst submit_to_arXiv
	cp orcidlink.sty submit_to_arXiv
	cp SciPost.cls submit_to_arXiv
	cp -r plots submit_to_arXiv
	cp -r code submit_to_arXiv
	cp Makefile submit_to_arXiv
	mv _minted-$(FILENAME) submit_to_arXiv/_minted-ms
	mv submit_to_arXiv/$(FILENAME).tex submit_to_arXiv/ms.tex
	# -i.bak is used for compatability across GNU and BSD/macOS sed
	# Change the FILENAME to ms while ignoring commented lines
	sed -i.bak '/^ *#/d;s/#.*//;0,/FILENAME/s/.*/FILENAME = ms/' submit_to_arXiv/Makefile
	# Use cache for minted
	# c.f. https://github.com/gpoore/minted/issues/113#issuecomment-223451550
	sed -i.bak 's/finalizecache/frozencache/' submit_to_arXiv/ms.tex
	# Cleanup temp files
	find submit_to_arXiv/ -name "*.bak" -type f -delete
	# arXiv requires .bib files to be compiled to .bbl files and will remove any .bib files
	find submit_to_arXiv/ -name "*.bib" -type f -delete
	tar -zcvf submit_to_arXiv.tar.gz submit_to_arXiv/
	rm -rf submit_to_arXiv
	$(MAKE) realclean
	if [ -f $(FILENAME).tex.bak ];then \
		mv $(FILENAME).tex.bak $(FILENAME).tex; \
	fi

clean_arXiv:
	if [ -f submit_to_arXiv.tar.gz ];then \
		rm submit_to_arXiv.tar.gz; \
	fi

deep_clean: realclean clean_arXiv
	rm -rf submit_to_arXiv
