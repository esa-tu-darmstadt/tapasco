use std::ptr::write_volatile;
use std::sync::Arc;
use memmap::MmapMut;
use crate::sim_client::SimClient;
use crate::protos::simcalls::{
    Data32,
    Data64,
    write_platform::Data,
    WritePlatform,
    ReadPlatform,
};

#[derive(Debug)]
pub enum MemoryType {
    Sim(Arc<SimClient>),
    Mmap(Arc<MmapMut>),
}

#[derive(Debug)]
pub enum ValType {
    U32(u32), U64(u64),
}

/*
 * Wrapper to write a single word (either 32 or 64 bit) to the provided memory.
 * In case of a hardware target this essentially wraps the write_volatile function and
 * for access to simulation targets it corresponds to a platform memory access.
 * Arguments:
 * memory: Reference to the memory that is being accessed
 * offset: Address offset into the memory area
 * value: the 32 or 64 bit value to be written at the specified address
 */
pub unsafe fn tapasco_write_volatile(memory: &MemoryType, offset: isize, value: ValType) {
    match memory {
        MemoryType::Sim(client) => {client.write_platform(WritePlatform{addr: offset as u64, data: Some(
            match value {
                ValType::U32(u_32) => Data::U32(Data32 {value: vec![u_32]}),
                ValType::U64(u_64) => Data::U64(Data64 {value: vec![u_64]})
            }
        )}).unwrap();},
        MemoryType::Mmap(mmap) => {
            let ptr = mmap.as_ptr().offset(offset);
            match value {
                ValType::U32(u_32) => write_volatile(ptr as *mut u32, u_32),
                ValType::U64(u_64) => write_volatile(ptr as *mut u64, u_64),
            };
        }
    };
}

/*
 * Wrapper to read a single word (either 32 or 64 bit) to the provided memory.
 * In case of a hardware target this essentially wraps the read_volatile function and
 * for access to simulation targets it corresponds to a platform memory access.
 * Arguments:
 * memory: Reference to the memory that is being accessed
 * offset: Address offset into the memory area
 * u_32: wether to read a 32 or 64 bit word
 */
pub unsafe fn tapasco_read_volatile(memory: &MemoryType, offset: isize, u_32: bool) -> u64 {
    match memory {
        MemoryType::Sim(client) => {
            let response = client.read_platform(ReadPlatform{addr: offset as u64, num_bytes: if u_32 { 4 } else { 8 }}).unwrap();
            if u_32 {
                let data: [u8; 4] = response.iter().map(|x| *x as u8).collect::<Vec<u8>>().try_into().unwrap();
                u32::from_ne_bytes(data) as u64
            } else {
                let data: [u8; 8] = response.iter().map(|x| *x as u8).collect::<Vec<u8>>().try_into().unwrap();
                u64::from_ne_bytes(data)
            }
        }
        MemoryType::Mmap(mmap) => {
            let ptr = mmap.as_ptr().offset(offset);
            if u_32 {
                ptr.cast::<u32>().read_volatile().into()
            } else {
                ptr.cast::<u64>().read_volatile().into()
            }
        }
    }
}