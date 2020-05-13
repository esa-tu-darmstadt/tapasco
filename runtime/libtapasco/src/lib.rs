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
extern crate generic_array;
extern crate libc;
extern crate page_size;
extern crate rand;
extern crate uom;
extern crate volatile_register;
#[macro_use]
extern crate snafu;
extern crate crossbeam;

pub mod allocator;
pub mod device;
pub mod dma;
pub mod ffi;
pub mod job;
pub mod pe;
pub mod scheduler;
pub mod tlkm;
