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
use core::fmt::Debug;
use memmap::MmapMut;
use std::sync::Arc;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Called start debug on unimplemented debug type {}", name))]
    Unsupported { name: String },

    #[snafu(display("Called start debug on PE without debug functionality"))]
    Non {},
}
type Result<T, E = Error> = std::result::Result<T, E>;

/// Create a DebugControl object
///
/// As the desired new function cannot be part of the DebugControl trait,
/// this secondary trait is used to specify how new looks like.
pub trait DebugGenerator: Debug {
    fn new(
        &self,
        arch_memory: &Arc<MmapMut>,
        name: String,
        offset: DeviceAddress,
        size: DeviceSize,
    ) -> Result<Box<dyn DebugControl + Send + Sync>>;
}

/// Enable a debugging mechanism
///
/// Implementation is entirely debug controller specific.
/// For instance an implementation for a soft core might start a GDB socket.
/// This function may block if necessary and the user should assume this by e.g. running
/// it in a secondary thread.
pub trait DebugControl: Debug {
    fn enable_debug(&mut self) -> Result<()>;
}

#[derive(Debug, Getters)]
pub struct UnsupportedDebugGenerator {}

impl DebugGenerator for UnsupportedDebugGenerator {
    fn new(
        &self,
        _arch_memory: &Arc<MmapMut>,
        name: String,
        _offset: DeviceAddress,
        _size: DeviceSize,
    ) -> Result<Box<dyn DebugControl + Send + Sync>> {
        Ok(Box::new(UnsupportedDebug { name: name }))
    }
}

/// PE supports debug but no specific implementation is provided.
///
/// Only returns errors...
#[derive(Debug, Getters)]
pub struct UnsupportedDebug {
    name: String,
}

impl DebugControl for UnsupportedDebug {
    fn enable_debug(&mut self) -> Result<()> {
        Err(Error::Unsupported {
            name: self.name.clone(),
        })
    }
}

#[derive(Debug, Getters)]
pub struct NonDebugGenerator {}

impl DebugGenerator for NonDebugGenerator {
    fn new(
        &self,
        _arch_memory: &Arc<MmapMut>,
        _name: String,
        _offset: DeviceAddress,
        _size: DeviceSize,
    ) -> Result<Box<dyn DebugControl + Send + Sync>> {
        Ok(Box::new(NonDebug {}))
    }
}

#[derive(Debug, Getters)]
pub struct NonDebug {}

impl DebugControl for NonDebug {
    fn enable_debug(&mut self) -> Result<()> {
        Err(Error::Non {})
    }
}
