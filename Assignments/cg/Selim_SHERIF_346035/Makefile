CXX=mpic++
LD=${CXX}
CXXFLAGS+=-Wall -Wextra -Werror -pedantic -Wno-error=cast-function-type -std=c++11 -pg -g -O2 -I${OPENBLAS_ROOT}/include
LDFLAGS+=-lm $(CXXFLAGS) -L${OPENBLAS_ROOT}/lib -lopenblas

OBJS=cg_main.o cg.o matrix_coo.o mmio.o

all: cgsolver

cgsolver: $(OBJS)
	$(LD) -o $@ $(OBJS) $(LDFLAGS)

clean:
	rm -f cgsolver *.o *~
