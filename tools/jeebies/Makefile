all: build

%.inc : %.jee
	sed -e 's/\x0d//' -e 's/.*/"&",/' $< > $@

build: jeebies.c he.inc be.inc
	$(CC) jeebies.c -o jeebies

clean:
	rm -f jeebies he.inc be.inc
