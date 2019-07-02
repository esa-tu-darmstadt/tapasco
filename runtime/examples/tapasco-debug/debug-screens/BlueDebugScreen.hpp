/**
 *  @file MonitorScreen.hpp
 *  @brief  Register monitor screen for the blue infrastructure of TPC.
 *  @author J. Hofmann, TU Darmstadt (hofmann@esa.tu-darmstadt.de)
 **/
#ifndef BLUE_DEBUG_SCREEN_HPP__
#define BLUE_DEBUG_SCREEN_HPP__

#include <tapasco.hpp>
extern "C" {
#include <platform.h>
}
#include "MenuScreen.hpp"

class BlueDebugScreen : public MenuScreen {
public:
  BlueDebugScreen(Tapasco *tapasco) : MenuScreen("Blue Monitor", vector<string>()), tapasco(*tapasco) {
    delay_us = 250;
    // We go with eight interrupts for now...
    for (int i = 0; i < total_interrupts; ++i) {
      interrupt_data d;
      intr.interrupts.push_back(d);
    }
    int pba_vecs = (total_interrupts / 64) + ((total_interrupts % 64) != 0);
    for (int i = 0; i < pba_vecs; ++i) {
      intr.pba.push_back(0);
    }
    platform_info_t info;
    tapasco->info(&info);
    dma_addr = info.base.platform[PLATFORM_COMPONENT_DMA0];
    intc_addr = info.base.platform[PLATFORM_COMPONENT_INTC0];

    uint64_t accumulated_delay = 199;
    platform_write_ctl(tapasco->platform_device(), dma_addr + 80, sizeof(accumulated_delay), &accumulated_delay, PLATFORM_CTL_FLAGS_RAW);
    platform_write_ctl(tapasco->platform_device(), dma_addr + 104, sizeof(accumulated_delay), &accumulated_delay, PLATFORM_CTL_FLAGS_RAW);
  }
  virtual ~BlueDebugScreen() {}

protected:
  virtual void render() {
    constexpr int rowc = 5;
    constexpr int colc = 16;
    const int h = (rows - 3) / rowc;
    const int w = cols / colc;
    int start_row = (rows - 3 - h * rowc) / 2;
    int start_col = (cols - w * colc) / 2;
    render_dma(start_row, start_col);
    start_col += 80;
    render_msix(start_row, start_col);
  }

  virtual int perform(const int choice) {
    if (choice == ERR) delay();
    return choice;
  }

  virtual void update() {
    // Update BlueDMA data
    platform_read_ctl(tapasco.platform_device(), dma_addr + 0, sizeof(dma.host_addr), &dma.host_addr, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 8, sizeof(dma.fpga_addr), &dma.fpga_addr, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 16, sizeof(dma.transfer_length), &dma.transfer_length, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 24, sizeof(dma.id), &dma.id, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 32, sizeof(dma.cmd), &dma.cmd, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 40, sizeof(dma.status), &dma.status, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 48, sizeof(dma.read_requests), &dma.read_requests, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 56, sizeof(dma.write_requests), &dma.write_requests, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 64, sizeof(dma.last_request_read), &dma.last_request_read, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 72, sizeof(dma.cycles_between_read), &dma.cycles_between_read, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 80, sizeof(dma.cycles_between_set_read), &dma.cycles_between_set_read, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 88, sizeof(dma.last_request_write), &dma.last_request_write, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 96, sizeof(dma.cycles_between_write), &dma.cycles_between_write, PLATFORM_CTL_FLAGS_RAW);
    platform_read_ctl(tapasco.platform_device(), dma_addr + 104, sizeof(dma.cycles_between_set_write), &dma.cycles_between_set_write, PLATFORM_CTL_FLAGS_RAW);
    ++dma.cycles_between_set_read; // Register contains num requests - 1
    ++dma.cycles_between_set_write; // Register contains num requests - 1

    // Update Interrupt data
    uint32_t base_addr = intc_addr;
    for (int i = 0; i < total_interrupts; ++i) {
      platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.interrupts[i].addr), &intr.interrupts[i].addr, PLATFORM_CTL_FLAGS_RAW);
      base_addr += 8;
      platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.interrupts[i].data), &intr.interrupts[i].data, PLATFORM_CTL_FLAGS_RAW);
      base_addr += 4;
      platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.interrupts[i].vector_control), &intr.interrupts[i].vector_control, PLATFORM_CTL_FLAGS_RAW);
      base_addr += 4;
    }

    base_addr = intc_addr + 0x8000;
    int pba_vecs = (total_interrupts / 64) + ((total_interrupts % 64) != 0);
    for (int i = 0; i < pba_vecs; ++i) {
      platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.pba[i]), &intr.pba[i], PLATFORM_CTL_FLAGS_RAW);
      base_addr += 8;
    }

    base_addr = intc_addr + 0x8100;
    platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.core_id), &intr.core_id, PLATFORM_CTL_FLAGS_RAW);
    base_addr += 4;
    platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.enableAndMask), &intr.enableAndMask, PLATFORM_CTL_FLAGS_RAW);
    base_addr += 4;
    platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.completedInterrupts), &intr.completedInterrupts, PLATFORM_CTL_FLAGS_RAW);
    base_addr += 4;
    platform_read_ctl(tapasco.platform_device(), base_addr, sizeof(intr.sentInterrupts), &intr.sentInterrupts, PLATFORM_CTL_FLAGS_RAW);
  }

private:
  struct dma_regs {
    uint64_t host_addr;
    uint64_t fpga_addr;
    uint64_t transfer_length;
    uint64_t id;
    uint64_t cmd;
    uint64_t status;
    uint64_t read_requests;
    uint64_t write_requests;
    uint64_t last_request_read;
    uint64_t cycles_between_read;
    uint64_t cycles_between_set_read;
    uint64_t last_request_write;
    uint64_t cycles_between_write;
    uint64_t cycles_between_set_write;
  };

  struct interrupt_data {
    uint64_t addr;
    uint32_t data;
    uint32_t vector_control;
  };

  struct intr_regs {
    std::vector<interrupt_data> interrupts;
    std::vector<uint64_t> pba;
    uint32_t core_id;
    uint32_t enableAndMask;
    uint32_t completedInterrupts;
    uint32_t sentInterrupts;
  };

  dma_regs dma;
  intr_regs intr;

  const int32_t total_interrupts = 131;

  void render_dma(int start_row, int start_col) {
    mvprintw(start_row++, start_col, "Host Address: %lx, FPGA Address: %lx", dma.host_addr, dma.fpga_addr);

    mvprintw(start_row++, start_col, "Transfer length: %ld, CMD: %lx", dma.transfer_length, dma.cmd);

    mvprintw(start_row++, start_col, "Read Requests: %ld, Write Requests: %ld", dma.read_requests, dma.write_requests);
    float frequency = 250000000.0f;
    float transfer_ms = (dma.last_request_read / frequency) * 1000;
    float transfer_mib = ((1000.0f / transfer_ms) * dma.transfer_length) / (1024.0f * 1024.0f);
    mvprintw(start_row++, start_col, "ms for last read request: %f / %f MiB", transfer_ms, transfer_mib);
    transfer_ms = ((dma.cycles_between_read / dma.cycles_between_set_read) / frequency) * 1000;
    transfer_mib = ((1000.0f / transfer_ms) * dma.transfer_length) / (1024.0f * 1024.0f);
    mvprintw(start_row++, start_col, "ms averaged over last %ld read request(s): %f / %f MiB", dma.cycles_between_set_read, transfer_ms, transfer_mib);

    transfer_ms = (dma.last_request_write / frequency) * 1000;
    transfer_mib = ((1000.0f / transfer_ms) * dma.transfer_length) / (1024.0f * 1024.0f);
    mvprintw(start_row++, start_col, "ms for last write request: %f / %f MiB", transfer_ms, transfer_mib);
    transfer_ms = ((dma.cycles_between_write / dma.cycles_between_set_write) / frequency) * 1000;
    transfer_mib = ((1000.0f / transfer_ms) * dma.transfer_length) / (1024.0f * 1024.0f);
    mvprintw(start_row++, start_col, "ms averaged over last %ld write request(s): %f / %f MiB", dma.cycles_between_set_write, transfer_ms, transfer_mib);
  }

  void render_msix(int start_row, int start_col) {
    mvprintw(start_row++, start_col, "Core ID: %x", intr.core_id);
    for (int i = 0; i < 8; ++i) {
      if (!intr.interrupts[i].vector_control) {
        mvprintw(start_row++, start_col, "Interrupt %d Address: %016lx Data: %08x Vector: %08x", i, intr.interrupts[i].addr, intr.interrupts[i].data, intr.interrupts[i].vector_control);
      }
    }
    int pba_vecs = (total_interrupts / 64) + ((total_interrupts % 64) != 0);
    for (int i = 0; i < pba_vecs; ++i) {
      mvprintw(start_row++, start_col, "PBA %3d - %3d: %16lx", i * 64, i * 64 + 63, intr.pba[i]);
    }
    mvprintw(start_row++, start_col, "Enable: %x Mask: %x", (intr.enableAndMask >> 16) & 0x1, intr.enableAndMask & 0x1);
    mvprintw(start_row++, start_col, "Sent Interrupts: %d", intr.sentInterrupts);
    mvprintw(start_row++, start_col, "Completed Interrupts: %d", intr.completedInterrupts & 0xFFFF);
    mvprintw(start_row++, start_col, "Interrupt Sent delay: %d", (intr.completedInterrupts >> 16) & 0xFFFF);
  }

  Tapasco &tapasco;
  platform_ctl_addr_t dma_addr;
  platform_ctl_addr_t intc_addr;
};

#endif