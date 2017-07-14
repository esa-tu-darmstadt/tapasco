CXX ?= g++
CXXFLAGS = -g -O2 -Wall -Werror
LDFLAGS =

SRCS = Sudoku.cpp main.cpp Sudoku_HLS.cpp
OBJS = $(patsubst %.cpp,%.o,$(SRCS))

%.o : %.cpp
	$(CXX) $(CXXFLAGS) -c $^

sudoku : $(OBJS)
	$(CXX) -o $@ $^ $(LDFLAGS)

clean :
	@rm -rf *.o sudoku
