CXX ?= g++
CCFLAGS = -O2 -Wall -Werror -Wno-unknown-pragmas  -D__C_BENCH__
LDFLAGS = -lrt

SRCDIR = src
OBJDIR = obj
BINDIR = bin
SUBDIRS = $(OBJDIR) $(BINDIR)

SRCS = Sudoku.cpp Sudoku_HLS.cpp
OBJS = $(patsubst %.cpp,$(OBJDIR)/%.o,$(SRCS))

.PHONY: all clean subdirs $(SUBDIRS) test executable

all: $(SUBDIRS) $(BINDIR)/sudoku

executable: $(SUBDIRS) $(BINDIR)/sudoku

test: $(BINDIR)/sudoku
	@echo "### Running test ###"
	@$(BINDIR)/sudoku puzzles/easy_puzzles.txt

subdirs: $(SUBDIRS)

$(SUBDIRS):
	@echo "### Creating directory $@ ###"
	@mkdir -p $@

$(OBJDIR)/%.o : $(SRCDIR)/%.cpp
	@$(CXX) $(CCFLAGS) -c $^ -o $@

$(BINDIR)/sudoku : $(OBJS) $(OBJDIR)/main.o
	@echo "### Building C application ###"
	@$(CXX) $(LDFLAGS) -o $@ $^

check_ddr.txt: executable
	@echo "### Running C application to create check_ddr.txt ###"
	@$(BINDIR)/sudoku puzzles/easy_puzzles.txt > /dev/null

preload_ddr.txt: executable
	@echo "### Running C application to create preload_ddr.txt ###"
	@$(BINDIR)/sudoku puzzles/easy_puzzles.txt > /dev/null

clean :
	@rm -rf $(SUBDIRS) preload_ddr.txt check_ddr.txt
