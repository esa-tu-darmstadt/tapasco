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

#![recursion_limit = "1024"]

#[macro_use]
extern crate log;
#[macro_use]
extern crate getset;
#[macro_use]
extern crate nix;
extern crate chrono;
#[macro_use]
extern crate snafu;
extern crate bytes;
extern crate crossbeam;
extern crate env_logger;
extern crate lockfree;

pub mod allocator;
pub mod debug;
pub mod device;
pub mod dma;
pub mod dma_user_space;
pub mod ffi;
pub mod interrupt;
pub mod job;
pub mod pe;
pub mod scheduler;
pub mod vfio;
pub mod tlkm;
pub mod sim_client;
pub mod mmap_mut;
