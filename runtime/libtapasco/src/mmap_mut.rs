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

pub unsafe fn tapasco_read_volatile(memory: &MemoryType, offset: isize, u_32: bool) -> u64 {
    match memory {
        MemoryType::Sim(client) => client.read_platform(ReadPlatform{addr: offset as u64, num_bytes: if u_32 { 4 } else { 8 }}).unwrap() as u64,
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