/*
 * Copyright (c) 2014-2025 Embedded Systems and Applications, TU Darmstadt.
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

use once_cell::sync::Lazy;
use std::any::Any;
use std::fmt::Debug;
use std::fs::File;
use std::sync::{Arc, RwLock};
use memmap::MmapMut;
use crate::device::Device;

#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Error {
    #[snafu(display("Error during plugin initialization: {}", source))]
    PluginInitializationError { source: Box<dyn std::error::Error> },
}

type Result<T, E = Error> = std::result::Result<T, E>;

/// Trait to be implemented by all runtime plugins
pub trait Plugin : Debug + Any + Send + Sync {
    /// plugin initialization function
    fn init(device: &Device, memory: &Arc<MmapMut>, tlkm_file: &Arc<File>) -> Result<Box<dyn Plugin>> where Self: Sized;

    /// return whether plugin is available on current device
    fn is_available(&self) -> bool;
    fn as_any(&self) -> &dyn Any;
    fn as_any_mut(&mut self) -> &mut dyn Any;
}

type PluginFactory = Box<dyn Fn(&Device, &Arc<MmapMut>, &Arc<File>) -> Result<Box<dyn Plugin>> + Send + Sync>;
pub static PLUGIN_REGISTRY: Lazy<RwLock<Vec<PluginFactory>>> = Lazy::new(|| RwLock::new(Vec::new()));

/// Macro to register a new runtime plugin
/// All plugins are collected automatically during startup by ctor function
/// Initialization is done in device constructor
#[macro_export]
macro_rules! declare_plugin {
    ($plugin_type:ty) => {
        #[ctor::ctor]
        fn register_plugin_ctor() {
            let mut reg = crate::plugins::plugin::PLUGIN_REGISTRY.write().unwrap();
            reg.push(Box::new(|device: &Device, memory: &Arc<MmapMut>, tlkm_file: &Arc<File>| <$plugin_type>::init(device, memory, tlkm_file)));
        }
    }
}
