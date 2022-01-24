Parsing the index and digest structures for a volume of the 1930s WPA project *Annals of Cleveland*, and presenting them in a Hugo site. See [https://www.wallandbinkley.com/projects/2019/annals-of-cleveland/](https://www.wallandbinkley.com/projects/2019/annals-of-cleveland/) for the current output.

## To run

- Clone this repository
- Install the Hugo theme, which is in a Git submodule: ```git submodule update```
- Save the [full text](https://babel.hathitrust.org/cgi/ssd?id=iau.31858046133199#seq7) from HathiTrust into the source directory as ```1864.html```. You will need to be logged in to HathiTrust; otherwise this file will not contain the full text of the volume.
- Install ```hugo``` following instructions at [gohugo.io](https://gohugo.io)
- Install ruby dependencies: ```bundle install```
- Run ```./process.rb ./source/1864/1864-corrected.html``` - this parses the source file and populates the ```hugo/content``` and ```hugo/data``` directories```
- Start hugo: cd to the ```hugo``` directory and run ```hugo serve -D```
- Visit the local site at [http://localhost:1313/projects/2019/annals-of-cleveland](http://localhost:1313/projects/2019/annals-of-cleveland)

## To Do

- improve the regex in ```lib/abstract.rb``` to handle more ocr variants
- extend the regex and the hugo output to handle multi-column references
- learn more about hugo and improve the implementation
- etc. etc.

## Notes

Annals of Cleveland 1864

vol. 47 pt. 1 (1937)

https://babel.hathitrust.org/cgi/pt?id=iau.31858046133199&view=1up&seq=7

- TOC: image 11
- Classification Lists: image 17-23
- Abstracts: p.1-361
- Chronological Index: pp. 363-376
- Index: 377-444

Newspapers:

L: Cleveland Leader https://chroniclingamerica.loc.gov/lccn/sn83035143/

## Markup

Mark the sections of the volumes to show where they begin and end.

- #START\_CLASSIFICATION, #END\_CLASSIFICATION
- #START\_ABSTRACTS, #END\_ABSTRACTS
- #START\_CHRON, #END\_CHRON
- #START\_TERMS, #END\_TERMS
