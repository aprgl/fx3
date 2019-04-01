CC = gcc -pipe
CFLAGS = -O2 -fno-exceptions -W -Wall -Wformat
LDFLAGS = -lusb-1.0

all: libusb_fx3_example

libusb_fx3_example: libusb_fx3_example.o fx3.o
	$(CC) libusb_fx3_example.o fx3.o $(LDFLAGS) -o libusb_fx3_example

clean:
	-rm -f libusb_fx3_example fx3.o

.cc.o:
	$(CC) -c $(CFLAGS) $<

libusb_fx3_example.o: libusb_fx3_example.c fx3.h
fx3.o: fx3.c fx3.h
