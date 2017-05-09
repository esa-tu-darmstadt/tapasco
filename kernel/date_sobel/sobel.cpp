//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
#define STENCIL_SIZE 3
#define IMAGE_SIZE 128

#include <string.h>

bool check_bounds(int x, int y);
unsigned char bound(int in_dir);
char const stencil_x[STENCIL_SIZE][STENCIL_SIZE] = { { static_cast<char>(-1), static_cast<char>(0), static_cast<char>(1) }, { static_cast<char>(-2), static_cast<char>(0), static_cast<char>(2) }, { static_cast<char>(-1), static_cast<char>(0), static_cast<char>(1) } };
char const stencil_y[STENCIL_SIZE][STENCIL_SIZE] = { { static_cast<char>(1), static_cast<char>(2), static_cast<char>(1) }, { static_cast<char>(0), static_cast<char>(0), static_cast<char>(0) }, { static_cast<char>(-1),static_cast<char>(-2), static_cast<char>(-1) } };

void sobel(unsigned char if_input_image[IMAGE_SIZE * IMAGE_SIZE],
		unsigned char if_output_image[IMAGE_SIZE * IMAGE_SIZE]) {
	for (unsigned y = 0; y < IMAGE_SIZE; y++) {
		for (unsigned x = 0; x < IMAGE_SIZE; x++) {
			if (check_bounds(x, y)) {
				int x_dir = 0;
				int y_dir = 0;
				for (int xOffset = -1; xOffset <= 1; xOffset++) {
					for (int yOffset = -1; yOffset <= 1; yOffset++) {
						unsigned image_index = y + yOffset + (x + xOffset) * IMAGE_SIZE;
						int pixel = *(if_input_image + image_index);
						x_dir += pixel * stencil_x[1 + xOffset][1 + yOffset];
						y_dir += pixel * stencil_y[1 + xOffset][1 + yOffset];
					}
				}
				unsigned char edge_weight = bound(x_dir) + bound(y_dir);
				unsigned output_index = y + x * IMAGE_SIZE;
				*(if_output_image + output_index) = 255 - edge_weight;
			}
		}
	}
}

void sobel_memloc(unsigned char if_input_image[IMAGE_SIZE * IMAGE_SIZE],
		unsigned char if_output_image[IMAGE_SIZE * IMAGE_SIZE]) {
	unsigned char input_image[IMAGE_SIZE * IMAGE_SIZE];
	unsigned char output_image[IMAGE_SIZE * IMAGE_SIZE];
	memcpy(input_image, if_input_image, IMAGE_SIZE);
	for (unsigned y = 0; y < IMAGE_SIZE; y++) {
		for (unsigned x = 0; x < IMAGE_SIZE; x++) {
			if (check_bounds(x, y)) {
				int x_dir = 0;
				int y_dir = 0;
				for (int xOffset = -1; xOffset <= 1; xOffset++) {
					for (int yOffset = -1; yOffset <= 1; yOffset++) {
						unsigned image_index = y + yOffset + (x + xOffset) * IMAGE_SIZE;
						int pixel = *(input_image + image_index);
						x_dir += pixel * stencil_x[1 + xOffset][1 + yOffset];
						y_dir += pixel * stencil_y[1 + xOffset][1 + yOffset];
					}
				}
				unsigned char edge_weight = bound(x_dir) + bound(y_dir);
				unsigned output_index = y + x * IMAGE_SIZE;
				*(output_image + output_index) = 255 - edge_weight;
			}
		}
	}
	memcpy(if_output_image, output_image, IMAGE_SIZE);
}

void sobel_pipelined(unsigned char if_input_image[IMAGE_SIZE * IMAGE_SIZE],
		unsigned char if_output_image[IMAGE_SIZE * IMAGE_SIZE]) {
	for (unsigned y = 0; y < IMAGE_SIZE; y++) {
		for (unsigned x = 0; x < IMAGE_SIZE; x++) {
#pragma HLS pipeline
			if (check_bounds(x, y)) {
				int x_dir = 0;
				int y_dir = 0;
				for (int xOffset = -1; xOffset <= 1; xOffset++) {
					for (int yOffset = -1; yOffset <= 1; yOffset++) {
						unsigned image_index = y + yOffset + (x + xOffset) * IMAGE_SIZE;
						int pixel = *(if_input_image + image_index);
						x_dir += pixel * stencil_x[1 + xOffset][1 + yOffset];
						y_dir += pixel * stencil_y[1 + xOffset][1 + yOffset];
					}
				}
				unsigned char edge_weight = bound(x_dir) + bound(y_dir);
				unsigned output_index = y + x * IMAGE_SIZE;
				*(if_output_image + output_index) = 255 - edge_weight;
			}
		}
	}
}

void sobel_pipelined_memloc(unsigned char if_input_image[IMAGE_SIZE * IMAGE_SIZE],
		unsigned char if_output_image[IMAGE_SIZE * IMAGE_SIZE]) {
	unsigned char input_image[IMAGE_SIZE * IMAGE_SIZE];
	unsigned char output_image[IMAGE_SIZE * IMAGE_SIZE];
	memcpy(input_image, if_input_image, IMAGE_SIZE);
	for (unsigned y = 0; y < IMAGE_SIZE; y++) {
		for (unsigned x = 0; x < IMAGE_SIZE; x++) {
#pragma HLS pipeline
			if (check_bounds(x, y)) {
				int x_dir = 0;
				int y_dir = 0;
				for (int xOffset = -1; xOffset <= 1; xOffset++) {
					for (int yOffset = -1; yOffset <= 1; yOffset++) {
						unsigned image_index = y + yOffset + (x + xOffset) * IMAGE_SIZE;
						int pixel = *(input_image + image_index);
						x_dir += pixel * stencil_x[1 + xOffset][1 + yOffset];
						y_dir += pixel * stencil_y[1 + xOffset][1 + yOffset];
					}
				}
				unsigned char edge_weight = bound(x_dir) + bound(y_dir);
				unsigned output_index = y + x * IMAGE_SIZE;
				*(output_image + output_index) = 255 - edge_weight;
			}
		}
	}
	memcpy(if_output_image, output_image, IMAGE_SIZE);
}

bool check_bounds(int x, int y) {
	return x > 0 && x < IMAGE_SIZE - 1 && y > 0 && y < IMAGE_SIZE - 1;
}
unsigned char bound(int in_dir) {
	//return 0; //return in_dir > 255 ? 255 : in_dir;
	return in_dir > 255 ? 255 : in_dir;
}

#ifndef __SYNTHESIS__
// #define NOF_IMAGES 8
#define NOF_IMAGES 1

struct image {
	unsigned char data[IMAGE_SIZE * IMAGE_SIZE];
};

void call_site() {
	image * images = new image[NOF_IMAGES]();
	image * results = new image[NOF_IMAGES]();
	for (unsigned image_index = 0; image_index < NOF_IMAGES; image_index++) {
	#ifdef SOBEL_MEMLOC
		sobel_memloc(images[image_index].data, results[image_index].data);
	#else
	#ifdef SOBEL_PIPELINED
		sobel_pipelined(images[image_index].data, results[image_index].data);
	#else
	#ifdef SOBEL_PIPELINED_MEMLOC
		sobel_pipelined_memloc(images[image_index].data, results[image_index].data);
	#else
		sobel(images[image_index].data, results[image_index].data);
	#endif
	#endif
	#endif
	}
}

int main(int argc, char **argv) {
	call_site();
}
#endif
