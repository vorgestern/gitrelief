
CFLAGS=`pkg-config --cflags gtk+-3.0`
LIBS=`pkg-config --libs gtk+-3.0`

gcc $CFLAGS -g -O0 -o example-1 example-1.c $LIBS

valgrind --leak-check=full --num-callers=30 --log-file=vgdump.txt ./example-1
