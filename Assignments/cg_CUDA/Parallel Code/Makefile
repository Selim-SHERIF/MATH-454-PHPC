# Compilers / Linker
CC        := gcc
CXX       := g++
NVCC      := nvcc
LD        := $(NVCC)

# Paths
OPENBLAS_INCLUDE := ${OPENBLAS_ROOT}/include
OPENBLAS_LIB     := ${OPENBLAS_ROOT}/lib

# Flags
CFLAGS    := -std=c11 -Wall -Wextra -I$(OPENBLAS_INCLUDE)
CXXFLAGS  := -std=c++11 -Wall -Wextra -Werror -pedantic -I$(OPENBLAS_INCLUDE)
NVCCFLAGS := -std=c++11 -I$(OPENBLAS_INCLUDE)

LDFLAGS   := -lm -L$(OPENBLAS_LIB) -lopenblas

# Sources / Objects
CU_SRCS   := cg.cu
CPP_SRCS  := cg_main.cc matrix.cc matrix_coo.cc
C_SRCS    := mmio.c

OBJS      := cg.o \
             cg_main.o \
             matrix.o \
             matrix_coo.o \
             mmio.o

all: cgsolver

cgsolver: $(OBJS)
	$(LD) -o $@ $(OBJS) $(LDFLAGS)

# CUDA object
cg.o: cg.cu cg.hh matrix.hh matrix_coo.hh
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

# C++ objects
cg_main.o: cg_main.cc cg.hh mmio.h
	$(CXX) $(CXXFLAGS) -c $< -o $@

matrix.o: matrix.cc matrix.hh matrix_coo.hh
	$(CXX) $(CXXFLAGS) -c $< -o $@

matrix_coo.o: matrix_coo.cc matrix_coo.hh mmio.h
	$(CXX) $(CXXFLAGS) -c $< -o $@

# C object
mmio.o: mmio.c mmio.h
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f cgsolver $(OBJS)