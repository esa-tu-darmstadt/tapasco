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

use crate::tlkm::tlkm_ioctl_reg_interrupt;
use crate::tlkm::tlkm_register_interrupt;
use nix::sys::eventfd::eventfd;
use nix::sys::eventfd::EfdFlags;
use nix::unistd::close;
use nix::unistd::read;
use snafu::ResultExt;
use std::fs::File;
use std::os::unix::io::RawFd;
use std::os::unix::prelude::*;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Error creating interrupt eventfd: {}", source))]
    ErrorEventFD { source: nix::Error },

    #[snafu(display("Error reading interrupt eventfd: {}", source))]
    ErrorEventFDRead { source: nix::Error },

    #[snafu(display("Could not register eventfd with driver: {}", source))]
    ErrorEventFDRegister { source: nix::Error },
}

type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug, Getters, Setters)]
pub struct Interrupt {
    interrupt: RawFd,
}

impl Drop for Interrupt {
    fn drop(&mut self) {
        let _ = close(self.interrupt);
    }
}

/// Handles interrupts using TLKM and Eventfd
///
/// Registers the eventfd with the driver and makes sure to release it after use.
/// Supports blocking of the wait_for_interrupt method.
impl Interrupt {
    pub fn new(tlkm_file: &File, interrupt_id: usize, blocking: bool) -> Result<Self> {
        let fd = if blocking {
            eventfd(0, EfdFlags::empty()).context(ErrorEventFD)?
        } else {
            eventfd(0, EfdFlags::EFD_NONBLOCK).context(ErrorEventFD)?
        };
        let mut ioctl_fd = tlkm_register_interrupt {
            fd,
            pe_id: interrupt_id as i32,
        };

        unsafe {
            tlkm_ioctl_reg_interrupt(tlkm_file.as_raw_fd(), &mut ioctl_fd)
                .context(ErrorEventFDRegister)?;
        };

        Ok(Self { interrupt: fd })
    }

    /// Wait for an interrupt as indicated by the eventfd
    ///
    /// Returns the number of interrupts that have occured since the last time
    /// calling this function.
    /// Returns at least 1
    pub fn wait_for_interrupt(&self) -> Result<u64> {
        let mut buf = [0u8; 8];
        loop {
            let r = read(self.interrupt, &mut buf);
            match r {
                Ok(_) => {
                    return Ok(u64::from_ne_bytes(buf));
                }
                Err(e) => {
                    if e == nix::errno::Errno::EAGAIN {
                        std::thread::yield_now();
                    } else {
                        r.context(ErrorEventFDRead)?;
                    }
                }
            }
        }
    }

    /// Check if any interrupts have occured
    ///
    /// Returns the number of interrupts that have occured since the last time
    /// calling this function or 0 if none have occured.
    /// This function behaves like wait_for_interrupt if blocking mode has been selected
    /// as the `read` will block in this case until an interrupt occurs.
    pub fn check_for_interrupt(&self) -> Result<u64> {
        let mut buf = [0u8; 8];
        loop {
            let r = read(self.interrupt, &mut buf);
            match r {
                Ok(_) => {
                    return Ok(u64::from_ne_bytes(buf));
                }
                Err(e) => {
                    if e == nix::errno::Errno::EAGAIN {
                        return Ok(0);
                    } else {
                        r.context(ErrorEventFDRead)?;
                    }
                }
            }
        }
    }
}
