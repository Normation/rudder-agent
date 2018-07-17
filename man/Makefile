NAME = rudder

all: $(NAME).8

$(NAME).adoc: $(NAME).adoc.sh
	sh $(NAME).adoc.sh > $(NAME).adoc

$(NAME).8: $(NAME).adoc
	asciidoctor -b manpage $(NAME).adoc

clean:
	$(RM) $(NAME).8 $(NAME).adoc
