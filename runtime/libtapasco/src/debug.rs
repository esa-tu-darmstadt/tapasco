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

pub trait DebugGenerator: Debug {
    fn new(
        &self,
        arch_memory: &Arc<MmapMut>,
        name: String,
        offset: DeviceAddress,
        size: DeviceSize,
    ) -> Result<Box<dyn DebugControl + Send + Sync>>;
}

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
