/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

use crate::device::DeviceAddress;
use crate::device::DeviceSize;
use crate::dma::DMABufferAllocate;
use crate::dma::DMAControl;
use crate::dma::Error;
use crate::dma::ErrorInterrupt;
use crate::dma::FailedMMapDMA;
use crate::interrupt::Interrupt;
use crate::tlkm::tlkm_dma_buffer_allocate;
use crate::tlkm::tlkm_dma_buffer_op;
use crate::tlkm::tlkm_ioctl_dma_buffer_allocate;
use crate::tlkm::tlkm_ioctl_dma_buffer_from_dev;
use crate::tlkm::tlkm_ioctl_dma_buffer_to_dev;
use core::fmt::Debug;
use core::sync::atomic::AtomicU64;
use crossbeam::deque::{Injector, Steal};
use lockfree::queue::Queue;
use memmap::MmapMut;
use memmap::MmapOptions;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::prelude::*;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::MutexGuard;
use std::thread;
use volatile::Volatile;

impl<T> From<std::sync::PoisonError<T>> for Error {
    fn from(_error: std::sync::PoisonError<T>) -> Self {
        Self::MutexError {}
    }
}

type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug)]
struct DMABuffer {
    id: usize,
    size: usize,
    addr: u64,
    mapped: MmapMut,
}

/// Provides a DMA implementation using on device DMA engines controlled by user space
///
/// This implementation is highly configurable and is configured through the configuration options:
///
/// * dma.read_buffers: Number of read bounce buffers used
/// * dma.read_buffer_size: Size of each read buffer
/// * dma.write_buffers: Number of write bounce buffers used
/// * dma.write_buffer_size: Size of each write buffer
///
/// The implementation uses TLKM to allocate the required bounce buffers and retrieve interrupts.
#[derive(Debug, Getters)]
pub struct UserSpaceDMA {
    tlkm_file: Arc<File>,
    memory: Mutex<Arc<MmapMut>>,
    engine_offset: usize,
    to_dev_buffer: Injector<DMABuffer>,
    from_dev_buffer: Injector<DMABuffer>,
    read_int: Interrupt,
    write_int: Interrupt,
    write_out: Queue<DMABuffer>,
    write_cntr: AtomicU64,
    write_int_cntr: AtomicU64,
    read_cntr: AtomicU64,
    read_int_cntr: AtomicU64,
}

impl UserSpaceDMA {
    pub fn new(
        tlkm_file: &Arc<File>,
        offset: usize,
        read_interrupt: usize,
        write_interrupt: usize,
        memory: &Arc<MmapMut>,
        read_buf_size: usize,
        read_num_buf: usize,
        write_buf_size: usize,
        write_num_buf: usize,
    ) -> Result<Self> {
        trace!(
            "Using setting: Read {} x {}B, Write {} x {}B",
            read_num_buf,
            read_buf_size,
            write_num_buf,
            write_buf_size
        );

        let write_map = Injector::new();
        let read_map = Injector::new();

        for _ in 0..write_num_buf {
            let mut to_dev_buf = tlkm_dma_buffer_allocate {
                size: write_buf_size,
                from_device: false,
                buffer_id: 42,
                addr: 42,
            };
            unsafe {
                tlkm_ioctl_dma_buffer_allocate(tlkm_file.as_raw_fd(), &mut to_dev_buf)
                    .context(DMABufferAllocate)?;
            };

            trace!("Retrieved {:?} for to_dev_buffer.", to_dev_buf);

            write_map.push(DMABuffer {
                id: to_dev_buf.buffer_id,
                addr: to_dev_buf.addr,
                size: write_buf_size,
                mapped: unsafe {
                    MmapOptions::new()
                        .len(write_buf_size)
                        .offset(((4 + to_dev_buf.buffer_id) * 4096) as u64)
                        .map_mut(tlkm_file)
                        .context(FailedMMapDMA)?
                },
            });
        }

        for _ in 0..read_num_buf {
            let mut from_dev_buf = tlkm_dma_buffer_allocate {
                size: read_buf_size,
                from_device: true,
                buffer_id: 42,
                addr: 42,
            };
            unsafe {
                tlkm_ioctl_dma_buffer_allocate(tlkm_file.as_raw_fd(), &mut from_dev_buf)
                    .context(DMABufferAllocate)?;
            };

            trace!("Retrieved {:?} for from_dev_buffer.", from_dev_buf);

            read_map.push(DMABuffer {
                id: from_dev_buf.buffer_id,
                addr: from_dev_buf.addr,
                size: read_buf_size,
                mapped: unsafe {
                    MmapOptions::new()
                        .len(read_buf_size)
                        .offset(((4 + from_dev_buf.buffer_id) * 4096) as u64)
                        .map_mut(tlkm_file)
                        .context(FailedMMapDMA)?
                },
            });
        }

        Ok(Self {
            tlkm_file: tlkm_file.clone(),
            memory: Mutex::new(memory.clone()),
            engine_offset: offset,
            to_dev_buffer: write_map,
            from_dev_buffer: read_map,
            read_int: Interrupt::new(tlkm_file, read_interrupt, false).context(ErrorInterrupt)?,
            write_int: Interrupt::new(tlkm_file, write_interrupt, false).context(ErrorInterrupt)?,
            write_out: Queue::new(),
            write_cntr: AtomicU64::new(0),
            write_int_cntr: AtomicU64::new(0),
            read_int_cntr: AtomicU64::new(0),
            read_cntr: AtomicU64::new(0),
        })
    }

    /// Enqueue a DMA transfer in the DMA engine
    ///
    /// This function currently supports only BlueDMA.
    fn schedule_dma_transfer(
        &self,
        dma_engine_memory: &MutexGuard<Arc<MmapMut>>,
        addr_host: u64,
        addr_device: DeviceAddress,
        size: DeviceSize,
        from_device: bool,
    ) -> Result<()> {
        let mut offset = (self.engine_offset as usize) as isize;
        unsafe {
            let ptr = dma_engine_memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u64>;
            (*volatile_ptr).write(addr_host);
        };

        offset = (self.engine_offset as usize + 0x08) as isize;
        unsafe {
            let ptr = dma_engine_memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u64>;
            (*volatile_ptr).write(addr_device);
        };

        offset = (self.engine_offset as usize + 0x10) as isize;
        unsafe {
            let ptr = dma_engine_memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u64>;
            (*volatile_ptr).write(size);
        };

        offset = (self.engine_offset as usize + 0x20) as isize;
        unsafe {
            let ptr = dma_engine_memory.as_ptr().offset(offset);
            let volatile_ptr = ptr as *mut Volatile<u64>;
            (*volatile_ptr).write(if from_device { 0x10001000 } else { 0x10000001 });
        };

        Ok(())
    }

    fn wait_for_write(&self, next: bool, cntr: u64) -> Result<()> {
        if !next || self.to_dev_buffer.is_empty() {
            while (next && self.to_dev_buffer.is_empty())
                || (!next && self.write_int_cntr.load(Ordering::Relaxed) <= cntr)
            {
                let n = self
                    .write_int
                    .check_for_interrupt()
                    .context(ErrorInterrupt)?;
                for _ in 0..n {
                    self.write_int_cntr.fetch_add(1, Ordering::Relaxed);
                    match self.write_out.pop() {
                        Some(buf) => self.to_dev_buffer.push(buf),
                        None => return Err(Error::TooManyInterrupts {}),
                    }
                }
                thread::yield_now();
            }
        }

        Ok(())
    }

    /// Update the read completion counter
    ///
    /// Uses the eventfd interrupt mechanism
    fn update_interrupts(&self) -> Result<()> {
        let n = self
            .read_int
            .check_for_interrupt()
            .context(ErrorInterrupt)?;
        self.read_int_cntr.fetch_add(n, Ordering::Relaxed);

        Ok(())
    }

    /// Copy the read buffers that have been filled by the DMA engine to user space memory
    fn copyback_buffer(
        &self,
        data: &mut [u8],
        buf: &DMABuffer,
        offset: usize,
        btt: usize,
    ) -> Result<()> {
        unsafe {
            tlkm_ioctl_dma_buffer_from_dev(
                self.tlkm_file.as_raw_fd(),
                &mut tlkm_dma_buffer_op { buffer_id: buf.id },
            )
            .context(DMABufferAllocate)?;
        };

        data[offset..offset + btt].copy_from_slice(&buf.mapped[0..btt]);

        Ok(())
    }

    fn release_buffer(
        &self,
        used_buffers: &mut Vec<(u64, Option<DMABuffer>, usize, usize)>,
        data: &mut [u8],
    ) -> Result<()> {
        let read_int_cntr_used = self.read_int_cntr.load(Ordering::Relaxed);
        for (cntr, buf, offset, len) in used_buffers.iter_mut() {
            if *cntr < read_int_cntr_used {
                let buf_taken = buf.take();
                if let Some(b) = buf_taken {
                    self.copyback_buffer(data, &b, *offset, *len)?;
                    self.from_dev_buffer.push(b);
                };
            } else {
                break;
            }
        }

        used_buffers.retain(|(x, _y, _z, _a)| *x >= read_int_cntr_used);
        Ok(())
    }
}

impl DMAControl for UserSpaceDMA {
    fn copy_to(&self, data: &[u8], ptr: DeviceAddress) -> Result<()> {
        trace!(
            "Copy Host({:?}) -> Device(0x{:x}) ({} Bytes)",
            data.as_ptr(),
            ptr,
            data.len()
        );

        let mut ptr_buffer = 0;
        let mut ptr_device = ptr;
        let mut btt = data.len();

        let mut highest_used = 0;

        while btt > 0 {
            let mut buffer = loop {
                match self.to_dev_buffer.steal() {
                    Steal::Success(buffer) => break buffer,
                    Steal::Empty => self.wait_for_write(true, 0)?,
                    Steal::Retry => (),
                }
            };

            let btt_this = if btt < buffer.size { btt } else { buffer.size };

            unsafe {
                tlkm_ioctl_dma_buffer_from_dev(
                    self.tlkm_file.as_raw_fd(),
                    &mut tlkm_dma_buffer_op {
                        buffer_id: buffer.id,
                    },
                )
                .context(DMABufferAllocate)?;
            };

            buffer.mapped[0..btt_this].copy_from_slice(&data[ptr_buffer..ptr_buffer + btt_this]);

            unsafe {
                tlkm_ioctl_dma_buffer_to_dev(
                    self.tlkm_file.as_raw_fd(),
                    &mut tlkm_dma_buffer_op {
                        buffer_id: buffer.id,
                    },
                )
                .context(DMABufferAllocate)?;
            };

            {
                let dma_engine_memory = self.memory.lock()?;
                let addr = buffer.addr;
                self.write_out.push(buffer);
                self.schedule_dma_transfer(
                    &dma_engine_memory,
                    addr,
                    ptr_device,
                    btt_this as u64,
                    false,
                )?;
                highest_used = self.write_cntr.fetch_add(1, Ordering::Relaxed);
            }

            btt -= btt_this;
            ptr_buffer += btt_this;
            ptr_device += btt_this as u64;
        }

        self.wait_for_write(false, highest_used)?;

        Ok(())
    }

    fn copy_from(&self, ptr: DeviceAddress, data: &mut [u8]) -> Result<()> {
        trace!(
            "Copy Device(0x{:x}) -> Host({:?}) ({} Bytes)",
            ptr,
            data.as_mut_ptr(),
            data.len()
        );

        let mut ptr_buffer = 0;
        let mut ptr_device = ptr;
        let mut btt = data.len();

        let mut used_buffers: Vec<(u64, Option<DMABuffer>, usize, usize)> = Vec::new();

        while btt > 0 {
            let buffer = loop {
                self.update_interrupts()?;
                self.release_buffer(&mut used_buffers, data)?;

                match self.from_dev_buffer.steal() {
                    Steal::Success(buffer) => break buffer,
                    Steal::Empty => thread::yield_now(),
                    Steal::Retry => (),
                }
            };

            let btt_this = if btt < buffer.size { btt } else { buffer.size };

            unsafe {
                tlkm_ioctl_dma_buffer_to_dev(
                    self.tlkm_file.as_raw_fd(),
                    &mut tlkm_dma_buffer_op {
                        buffer_id: buffer.id,
                    },
                )
                .context(DMABufferAllocate)?;
            };

            let cntr = {
                let dma_engine_memory = self.memory.lock()?;
                self.schedule_dma_transfer(
                    &dma_engine_memory,
                    buffer.addr,
                    ptr_device,
                    btt_this as u64,
                    true,
                )?;
                self.read_cntr.fetch_add(1, Ordering::Relaxed)
            };

            used_buffers.push((cntr, Some(buffer), ptr_buffer, btt_this));

            btt -= btt_this;
            ptr_buffer += btt_this;
            ptr_device += btt_this as u64;
        }

        while !used_buffers.is_empty() {
            self.release_buffer(&mut used_buffers, data)?;
            self.update_interrupts()?;
            thread::yield_now();
        }

        Ok(())
    }
}
