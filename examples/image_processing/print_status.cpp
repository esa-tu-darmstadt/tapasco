#include <iostream>
#include <iomanip>
#include <fstream>
#include <sstream>
#include <chrono>
#include <ctime>
#include <vector>
#include <sys/utsname.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <signal.h>
#include <atomic>
#include <csignal>


int main(int argc, const char *argv[]) {
	int fd = open("/dev/HSA_AQL_QUEUE_0", O_RDWR, 0);
	if (fd < 0) {
		std::cout << "Could not open HSA_AQL_QUEUE_0" << std::endl;
		return -1;
	}
	uint64_t *arbiter_space = (uint64_t*) mmap(0, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 2 * getpagesize());
	if (arbiter_space == MAP_FAILED) {
		std::cout << "Couldn't get mapping" << std::endl;
		return -1;
	}

	uint64_t *signal_space = (uint64_t*) mmap(0, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 3 * getpagesize());
	if (signal_space == MAP_FAILED) {
		std::cout << "Couldn't get mapping" << std::endl;
		return -1;
	}

	std::cout << "Waiting for completion" << std::endl;

	for (int i = 0; i < 64; ++i) {
		std::cout << i << " " << std::hex << signal_space[i] << std::dec << std::endl;
	}

	// Print some status registers for debugging
	// Counter for signal sent and acked, should be equal
	std::cout << "Idle cycles " << arbiter_space[11] << std::endl;

	std::cout << "Fetch iterations " << arbiter_space[10] << std::endl;

	std::cout << "Packages Fetched is " << arbiter_space[22] << std::endl;

	std::cout << "Packages Invalidated is " << arbiter_space[23] << std::endl;

	std::cout << "Read_index is " << arbiter_space[24] << std::endl;

	std::cout << "Read_index_old is " << arbiter_space[25] << std::endl;

	std::cout << "Write_index is " << arbiter_space[26] << std::endl;

	std::cout << "Write_index_old is " << arbiter_space[27] << std::endl;


	munmap(arbiter_space, 0x1000);
	munmap(signal_space, 0x1000);
	close(fd);

	return EXIT_SUCCESS;
}
