#include <cstring> //png++ needs it (in this version)
#include <png++/png.hpp>

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

#include "hsa_types.h"
#include "hsa_aql_queue.h"
#include "hsa_dma.h"
#include "stringtools.h"
#include "cliparser.h"

inline uint64_t calculate_packet_index(uint64_t ptr) {
	return ptr % HSA_QUEUE_LENGTH;
}

std::atomic<bool> quit(false);    // signal flag

void got_signal(int)
{
	quit.store(true);
}

int main(int argc, const char *argv[]) {
	CLIParser cli;

	std::vector<std::string> args;
	args.push_back("help");
	args.push_back("debug");
	args.push_back("convert_grayscale");
	args.push_back("operation");
	args.push_back("outfile");

	try{
		cli.parse_arguments(argc, argv, args);
	}catch(const std::invalid_argument &exc){
		std::cerr << "error: " << exc.what() << std::endl;
		return EXIT_FAILURE;
	}

	if(cli.key_exists("help")){
		std::cout << "image processing tool with HSA backend" << std::endl;
		std::cout << std::endl;
		std::cout << "options:" << std::endl;
		std::cout << "	--debug:             enables debugging output" << std::endl;
		std::cout << "	--convert_grayscale: convert RGB image to grayscale" << std::endl;
		std::cout << "	--operation=<val>:   image operation to perform" << std::endl;
		std::cout << "	--outfile:           name of the output image" << std::endl;
		std::cout << std::endl;
		std::cout << "supported image operations:" << std::endl;
		std::cout << "	SOBELX3x3" << std::endl;
		std::cout << "	SOBELY3x3" << std::endl;
		std::cout << "	SOBELXY3x3" << std::endl;
		std::cout << "	SOBELX5x5" << std::endl;
		std::cout << "	SOBELY5x5" << std::endl;
		std::cout << "	SOBELXY5x5" << std::endl;
		std::cout << "	GAUSS3x3" << std::endl;
		std::cout << "	GAUSS5x5" << std::endl;
		std::cout << "	MIN_FILTER3x3" << std::endl;
		std::cout << "	MIN_FILTER5x5" << std::endl;
		std::cout << "	MAX_FILTER3x3" << std::endl;
		std::cout << "	MAX_FILTER5x5" << std::endl;
		std::cout << "	MEDIAN_FILTER3x3" << std::endl;
		std::cout << "	MEDIAN_FILTER5x5" << std::endl;
		std::cout << std::endl;
		std::cout << "example usage:" << std::endl;
		std::cout << "	./imgproc --operation=GAUSS3x3 --convert_grayscale image.png" << std::endl;
		return EXIT_SUCCESS;
	}

	bool debug_mode = false;
	if(cli.key_exists("debug")){
		debug_mode = true;
	}

	if(!cli.key_exists("file")){
		std::cerr << "ERROR: no file to convert specified!!" << std::endl;
		return EXIT_FAILURE;
	}
	std::string infile = cli.getValue("file");

	int colormodel = UINT8_RGB;
	bool convert_grayscale = false;
	if(cli.key_exists("convert_grayscale")){
		convert_grayscale = true;
		colormodel = UINT16_GRAY_SCALE;
	}

	int op = 0;
	if(cli.key_exists("operation")){
		std::string opstring = cli.getValue("operation");
		op = get_optype_int_representation(opstring);
		if(op == -1){
			std::cerr << "ERROR: unknown operation type" << std::endl;
			return EXIT_FAILURE;
		}
	}else{
		std::cerr << "ERROR: choose operation to perform (--help for more info)" << std::endl;
		return EXIT_FAILURE;
	}

	unsigned int pixel_bitwidth = 32;
	if(convert_grayscale){
		pixel_bitwidth = 16;
	}

	std::vector<std::string> path_tokens;
	std::vector<std::string> file_tokens;
	tokenize(infile,path_tokens,'/');
	tokenize(path_tokens[path_tokens.size()-1],file_tokens,'.');
	if(file_tokens.size() < 2){
		std::cerr << "file has no filetype extension" << std::endl;
		return EXIT_FAILURE;
	}

	std::string outfile = file_tokens[0];
	if(file_tokens[1].compare("png")==0){
		outfile += "_processed.png";
	}else{
		std::cerr << "only .png files supported" << std::endl;
		return EXIT_FAILURE;
	}

	if(cli.key_exists("outfile")){
		outfile = cli.getValue("outfile");
	}

	signal(SIGINT, got_signal);

	hsa_dma mem;
	aql_queue queue;

	// Aquiring signal to be used as completion signal
	// Allocating signal, we'll receive:
	//  - Device Physical Address to put in AQL packets
	//  - Index of the signal that has been allocated to access the signal in the mapped dma_mem
	hsa_ioctl_params completion_signal;
	queue.allocate_signal(&completion_signal);
	uint64_t *completion = queue.get_signal_userspace(completion_signal);
	// Initialize value of completion signal
	__atomic_store_n(completion,1,__ATOMIC_RELEASE);

	hsa_ioctl_params doorbell_signal;
	queue.allocate_signal(&doorbell_signal);
	uint64_t *doorbell = queue.get_signal_userspace(doorbell_signal);

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

	// Fetch write pointer from the hardware -> Make sure we enqueue our packages at the correct location
	uint64_t current_write_ptr = arbiter_space[26];
	if(debug_mode){
		std::cout << "Fetched old write pointer from hardware as " << current_write_ptr << std::endl;
	}

	*doorbell = current_write_ptr;
	// Announce doorbell signal to the hardware
	queue.set_doorbell(doorbell_signal);

	uint64_t offset_kernargs = 0x0;
	uint64_t offset_image = 0x1000;

	// copy image to specific memory area
	png::image<png::rgb_pixel> src_img(infile);
	uint8_t *dma_area = static_cast<uint8_t*>(mem.getVirtualAddr()) + offset_image;

	uint64_t max_size = (4 * 1024 * 1024) - offset_image;
	uint64_t actual_size = src_img.get_height() * src_img.get_width();
	actual_size = convert_grayscale ? actual_size * 2 : actual_size * 3;
	if(debug_mode){
		std::cout << "Using " << actual_size << "byte of " << max_size << " byte." << std::endl;
	}
	if(actual_size >= max_size){
		std::cout << "ERROR: required memory exceeds current limit!" << std::endl;
		return EXIT_FAILURE;
	}

	for (unsigned int j = 0; j < (unsigned int)src_img.get_height(); ++j) {
		for (unsigned int i = 0; i < (unsigned int)src_img.get_width(); ++i) {
			// in pngpp (0,0) is the TOP left corner!
			png::rgb_pixel pix = src_img.get_pixel(i,j);
			if(convert_grayscale){
				float luminance = 0.2126f*(static_cast<float>(pix.red)/0xFF)
						+ 0.7152f*(static_cast<float>(pix.green)/0xFF)
						+ 0.0722f*(static_cast<float>(pix.blue)/0xFF);
				uint16_t gs_val = static_cast<uint16_t>(luminance*((1 << pixel_bitwidth)-1));
				uint16_t *pix_ptr = reinterpret_cast<uint16_t*>(dma_area);
				pix_ptr += j*src_img.get_width()+i;
				*pix_ptr = gs_val;
			}else{
				uint8_t r_val = static_cast<uint8_t>(pix.red);
				uint8_t g_val = static_cast<uint8_t>(pix.green);
				uint8_t b_val = static_cast<uint8_t>(pix.blue);
				uint8_t *pix_ptr = dma_area;
				pix_ptr += (j*src_img.get_width()+i)*3;
				*pix_ptr = b_val;
				pix_ptr += 1;
				*pix_ptr = r_val;
				pix_ptr += 1;
				*pix_ptr = g_val;
			}
		}
	}

	// single producer queue
	hsa_kernel_dispatch_packet_t *pktQueue = (hsa_kernel_dispatch_packet_t *)queue.get_package_queue();
	hsa_kernel_dispatch_packet_t *packet = pktQueue + calculate_packet_index(current_write_ptr);

	uint64_t cmpl_sig = queue.get_signal_device(completion_signal);
	hsa_signal_t hsa_cmpl_signal = {cmpl_sig};

	// Adding kernags
	uint64_t *kernargs = (uint64_t*)((uint64_t)mem.getVirtualAddr() + offset_kernargs);
	kernargs[0] = mem.getDevAddr() + offset_image;
	kernargs[1] = mem.getDevAddr() + offset_image;
	*(((uint8_t*)kernargs)+16) = (uint8_t)colormodel;
	*(((uint8_t*)kernargs)+17) = (uint8_t)CLAMP_TO_ZERO;

	// populate kernel
	packet->kernel_object = (uint64_t)op;
	packet->kernarg_address = (void *)(mem.getDevAddr() + offset_kernargs);
	packet->grid_size_x = src_img.get_width();
	packet->grid_size_y = src_img.get_height();
	packet->completion_signal = hsa_cmpl_signal;

	uint32_t packet_format = ((uint32_t)setup(2) << 16) | header(HSA_PACKET_TYPE_KERNEL_DISPATCH);
	__atomic_store_n((uint32_t*)packet,packet_format,__ATOMIC_RELEASE);

	if(debug_mode){
		std::cout << std::hex << "Header: " << packet->header << std::endl;
		std::cout << std::hex << "Setup: " << packet->setup << std::endl;
		std::cout << std::hex << "Kernel Object: " << packet->kernel_object << std::endl;
		std::cout << std::hex << "Size X: " << packet->grid_size_x << std::endl;
		std::cout << std::hex << "Size Y: " << packet->grid_size_y << std::endl;
		std::cout << std::hex << "Signal: " << packet->completion_signal.handle << std::endl;
		std::cout << std::hex << "Kernarg Address: " << packet->kernarg_address << std::endl;
		std::cout << std::hex << "Kernarg 0: " << std::hex << kernargs[0] << std::dec << std::endl;
		std::cout << std::hex << "Kernarg 1: " << std::hex << kernargs[1] << std::dec << std::endl;
		std::cout << std::hex << "Kernarg 2: " << std::hex << kernargs[2] << std::dec << std::endl;
	}

	__atomic_fetch_add(doorbell,1,__ATOMIC_RELEASE);

	while (__atomic_load_n(completion,__ATOMIC_ACQUIRE)) {
		if(debug_mode){
			std::cout << "Waiting for completion" << std::endl;

			for(int i = 0; i < 64; ++i) {
				std::cout << i << " " << signal_space[i] << std::endl;
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
		}

		if( quit.load() ) break;    // exit normally after SIGINT
		sleep(1);
	}

	// generate png from dma image area
	png::image<png::rgb_pixel> dst_img(src_img.get_width(),src_img.get_height());

	for (unsigned int y = 0; y < (unsigned int)src_img.get_height(); ++y) {
		for (unsigned int x = 0; x < (unsigned int)src_img.get_width(); ++x) {
			if(convert_grayscale){
				uint16_t *pix_ptr = reinterpret_cast<uint16_t*>(dma_area);
				pix_ptr += y*src_img.get_width()+x;

				unsigned int gs_val = *pix_ptr;
				unsigned int scaling_factor = ((pixel_bitwidth/8)-1)*8;
				unsigned int intensity = gs_val >> scaling_factor;
				dst_img[y][x] = png::rgb_pixel(intensity,intensity,intensity);
			}else{
				uint8_t *pix_ptr = static_cast<uint8_t*>(dma_area);
				pix_ptr += (y*src_img.get_width()+x)*3;

				uint8_t blue  = *pix_ptr;
				pix_ptr += 1;
				uint8_t red  = *pix_ptr;
				pix_ptr += 1;
				uint8_t green   = *pix_ptr;
				dst_img[y][x] = png::rgb_pixel(red,green,blue);
			}
		}
	}
	dst_img.write(outfile);

	queue.unset_doorbell(doorbell_signal);
	queue.deallocate_signal(doorbell_signal);
	queue.deallocate_signal(completion_signal);

	munmap(arbiter_space, 0x1000);
	close(fd);

	return EXIT_SUCCESS;
}
