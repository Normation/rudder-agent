NAME = rudder

all: $(NAME).1 $(NAME).html

sourcefile: $(NAME).asciidoc.sh
	sh $(NAME).asciidoc.sh

$(NAME).1: sourcefile
	a2x --doctype manpage --format manpage $(NAME).asciidoc

$(NAME).html: sourcefile
	asciidoctor -d manpage $(NAME).asciidoc

clean:
	$(RM) $(NAME).1 $(NAME).html $(NAME).asciidoc
