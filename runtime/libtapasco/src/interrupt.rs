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

use crate::tlkm::tlkm_ioctl_reg_platform;
use crate::tlkm::tlkm_ioctl_reg_user;
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

impl Interrupt {
    pub fn new(
        tlkm_file: &File,
        interrupt_id: usize,
        user_interrupt: bool,
        blocking: bool,
    ) -> Result<Interrupt> {
        let fd = if blocking {
            eventfd(0, EfdFlags::empty()).context(ErrorEventFD)?
        } else {
            eventfd(0, EfdFlags::EFD_NONBLOCK).context(ErrorEventFD)?
        };
        let mut ioctl_fd = tlkm_register_interrupt {
            fd: fd,
            pe_id: interrupt_id as i32,
        };

        if user_interrupt {
            unsafe {
                tlkm_ioctl_reg_user(tlkm_file.as_raw_fd(), &mut ioctl_fd)
                    .context(ErrorEventFDRegister)?;
            };
        } else {
            unsafe {
                tlkm_ioctl_reg_platform(tlkm_file.as_raw_fd(), &mut ioctl_fd)
                    .context(ErrorEventFDRegister)?;
            };
        }

        Ok(Interrupt { interrupt: fd })
    }

    pub fn wait_for_interrupt(&self) -> Result<()> {
        let mut buf = [0u8; 8];
        loop {
            let r = read(self.interrupt, &mut buf);
            match r {
                Ok(_) => {
                    return Ok(());
                }
                Err(e) => {
                    let e_no = e.as_errno();
                    match e_no {
                        Some(e_no_matched) => {
                            if e_no_matched != nix::errno::Errno::EAGAIN {
                                r.context(ErrorEventFDRead)?;
                            } else {
                                std::thread::yield_now();
                            }
                        }
                        None => {
                            r.context(ErrorEventFDRead)?;
                        }
                    }
                }
            }
        }
    }
}
