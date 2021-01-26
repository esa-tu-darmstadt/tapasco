extern crate snafu;
extern crate tapasco;
#[macro_use]
extern crate log;

use snafu::{ResultExt, Snafu};
use std::collections::HashMap;
use std::str;
use tapasco::tlkm::*;

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Allocator Error: {}", source))]
    AllocatorError { source: tapasco::allocator::Error },

    #[snafu(display("DMA Error: {}", source))]
    DMAError { source: tapasco::dma::Error },

    #[snafu(display("Invalid subcommand"))]
    UnknownCommand {},
    #[snafu(display("Failed to initialize TLKM object: {}", source))]
    TLKMInit { source: tapasco::tlkm::Error },

    #[snafu(display("Failed to decode TLKM device: {}", source))]
    DeviceInit { source: tapasco::device::Error },

    #[snafu(display("Error while executing PE: {}", source))]
    PEError { source: tapasco::pe::Error },

    #[snafu(display("IO Error: {}", source))]
    IOError { source: std::io::Error },

    #[snafu(display("Register {} not found.", name))]
    RegNotFound { name: String },
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

fn read_register(pe: &mut tapasco::pe::PE, reg: u64) -> Result<u64> {
    pe.set_arg(0, tapasco::device::PEParameter::Single64(0))
        .context(PEError)?;
    pe.set_arg(1, tapasco::device::PEParameter::Single64(reg))
        .context(PEError)?;
    pe.start().context(PEError)?;
    let (ret, _) = pe.release(true).context(PEError)?;

    Ok(ret)
}

fn read_register_values(
    pe: &mut tapasco::pe::PE,
    reg_values: &mut Vec<(String, u64)>,
) -> Result<()> {
    let len = reg_values.len() as u64;
    for (i, (name, value)) in reg_values.iter_mut().enumerate() {
        let r = read_register(pe, 1 + len + i as u64)?;
        println!("Got {} -> {}", name, r);
        *value = r;
    }

    Ok(())
}

fn write_register(
    pe: &mut tapasco::pe::PE,
    reg_values: &Vec<(String, u64)>,
    name: &str,
    value: u64,
) -> Result<()> {
    let idx = reg_values
        .iter()
        .position(|(n, _val)| return n == name)
        .ok_or(Error::RegNotFound {
            name: name.to_string(),
        })?;

    pe.set_arg(0, tapasco::device::PEParameter::Single64(1))
        .context(PEError)?;
    pe.set_arg(
        1,
        tapasco::device::PEParameter::Single64(1 + reg_values.len() as u64 + idx as u64),
    )
    .context(PEError)?;
    pe.set_arg(2, tapasco::device::PEParameter::Single64(value))
        .context(PEError)?;
    pe.start().context(PEError)?;
    pe.release(false).context(PEError)?;

    Ok(())
}

fn write_iic_reg(mem: &mut [u8], reg: u32, val: u32) {
    unsafe {
        let ptr = mem.as_ptr().offset(reg as isize);
        let volatile_ptr = ptr as *mut u32;
        volatile_ptr.write_volatile(val);
    }
}

fn read_iic_reg(mem: &[u8], reg: u32) -> u32 {
    unsafe {
        let ptr = mem.as_ptr().offset(reg as isize);
        let volatile_ptr = ptr as *const u32;
        volatile_ptr.read_volatile()
    }
}

fn iic_init(iic: &mut [u8]) {
    iic_reset(iic);

    write_iic_reg(iic, 0x120, 0xF); // setFIFOPIRQ

    // resetTXFIFO
    let mut control = iic_control(iic);
    control |= 0b10;
    iic_write_control(iic, control);

    //write_iic_reg(iic, 0x20, 0xF); // reset ISR register

    // enableDevice
    control = iic_control(iic);
    control |= 0b1;
    iic_write_control(iic, control);

    // disableTXFIFOReset
    control = iic_control(iic);
    control &= !(1 << 1);
    iic_write_control(iic, control);

    // disableGeneralCall
    control = iic_control(iic);
    control &= !(1 << 6);
    iic_write_control(iic, control);
}

fn iic_enqueue(iic: &mut [u8], val: u8, start: bool, stop: bool) {
    write_iic_reg(
        iic,
        0x108,
        (stop as u32) << 9 | (start as u32) << 8 | (val as u32),
    );
}

fn iic_dequeue(iic: &[u8]) -> u8 {
    read_iic_reg(iic, 0x10c) as u8
}

fn iic_control(iic: &[u8]) -> u32 {
    read_iic_reg(iic, 0x100)
}

fn iic_write_control(iic: &mut [u8], val: u32) {
    write_iic_reg(iic, 0x100, val);
}

fn iic_status(iic: &[u8]) -> u8 {
    read_iic_reg(iic, 0x104) as u8
}

fn iic_isr(iic: &[u8]) -> u8 {
    read_iic_reg(iic, 0x20) as u8
}

fn iic_reset(iic: &mut [u8]) {
    write_iic_reg(iic, 0x40, 0xA);
}

fn iic_status_tx_empty(val: u8) -> bool {
    val & (1 << 7) != 0
}

fn iic_status_rx_empty(val: u8) -> bool {
    val & (1 << 6) != 0
}

fn iic_status_bb(val: u8) -> bool {
    val & (1 << 2) != 0
}

fn iic_enable_gpio(iic: &mut [u8], val: u32) {
    write_iic_reg(iic, 0x124, val);
}

fn iic_read_simple(iic: &mut [u8], device: u8) -> u8 {
    iic_init(iic);
    let mut status = iic_status(iic);
    trace!("Waiting for device ready {:b}", status);
    while !(iic_status_rx_empty(status) && iic_status_tx_empty(status) && !iic_status_bb(status)) {
        status = iic_status(iic);
        std::thread::sleep(std::time::Duration::from_millis(500));
    }
    trace!("Starting read");
    iic_enqueue(iic, device << 1 | 1, true, false);
    iic_enqueue(iic, 1, false, true);

    trace!("Waiting for result");
    status = iic_status(iic);
    while iic_status_rx_empty(status) {
        status = iic_status(iic);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }

    iic_dequeue(iic)
}

fn iic_read(iic: &mut [u8], device: u8, register: u8) -> u8 {
    iic_init(iic);
    let mut status = iic_status(iic);
    trace!("Waiting for device ready {:b}", status);
    while !(iic_status_rx_empty(status) && iic_status_tx_empty(status) && !iic_status_bb(status)) {
        status = iic_status(iic);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    trace!("Starting read");
    iic_enqueue(iic, device << 1 | 0, true, false);
    iic_enqueue(iic, register, false, false);
    iic_enqueue(iic, device << 1 | 1, true, false);
    iic_enqueue(iic, 1, false, true);

    trace!("Waiting for result");
    status = iic_status(iic);
    while iic_status_rx_empty(status) {
        status = iic_status(iic);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }

    iic_dequeue(iic)
}

fn iic_write(iic: &mut [u8], device: u8, register: u8, values: &[u8]) {
    iic_init(iic);
    let mut status = iic_status(iic);
    trace!(
        "Preparing write to {:x} {:x} {:?} {}",
        device,
        register,
        values,
        values.len()
    );
    trace!("Waiting for device ready {:b}", status);
    while !(iic_status_rx_empty(status) && iic_status_tx_empty(status) && !iic_status_bb(status)) {
        status = iic_status(iic);
        info!("Waiting for device ready {:b}", status);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    trace!("Starting write");
    iic_enqueue(iic, device << 1 | 0, true, false);
    iic_enqueue(iic, register, false, values.len() == 0);
    for (i, v) in values.iter().enumerate() {
        iic_enqueue(iic, *v, false, i + 1 == values.len());
    }

    trace!("Waiting for completion");
    status = iic_status(iic);
    while !(iic_status_rx_empty(status) && iic_status_tx_empty(status) && !iic_status_bb(status)) {
        status = iic_status(iic);
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    let isr = iic_isr(iic);
    if isr & 2 != 0 {
        error!("Got slave error {:b}", isr);
        write_iic_reg(iic, 0x20, 1 << 1);
    }
}

fn iic_write_check(iic: &mut [u8], device: u8, register: u8, values: &[u8]) {
    //iic_write(iic, device, register, values);
    for i in 0..values.len() {
        iic_write(iic, device, register + i as u8, &[values[i]]);
        let mut check = iic_read(iic, device, register + i as u8);
        while check != values[i] {
            trace!(
                "Retrying {} {} -> {} != {}",
                device,
                register + i as u8,
                values[i],
                check
            );
            iic_write(iic, device, register + i as u8, &[values[i]]);
            check = iic_read(iic, device, register + i as u8);
        }
    }
}

fn run() -> Result<()> {
    let tlkm = TLKM::new().context(TLKMInit)?;

    let mut devices = tlkm.device_enum(&HashMap::new()).context(TLKMInit)?;

    let mut main_device = devices.pop().expect("No tapasco device found.");

    main_device
        .change_access(tapasco::tlkm::tlkm_access::TlkmAccessExclusive)
        .context(DeviceInit)?;

    match main_device
        .get_platform_component_as_pe("PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER")
        .context(DeviceInit)
    {
        Ok(mut pe) => {
            pe.enable_interrupt().context(PEError)?;

            let mut regs = Vec::new();

            let num_regs = read_register(&mut pe, 0)?;

            info!("Found {} status and control registers in PE.", num_regs);

            for r in 0..num_regs {
                let name_v = &u64::to_be_bytes(read_register(&mut pe, 1 + r)?);
                regs.push((
                    str::from_utf8(name_v)
                        .expect("Not a valid register name.")
                        .to_string(),
                    0u64,
                ));
            }
            read_register_values(&mut pe, &mut regs)?;

            info!("Found the following registers: {:?}.", regs);

            write_register(&mut pe, &regs, " program", 1)?;

            for _ in 0..10 {
                read_register_values(&mut pe, &mut regs)?;

                info!("Found the following registers: {:?}.", regs);
                std::thread::sleep(std::time::Duration::from_millis(500));
            }
        }
        Err(_e) => {
            info!("Assuming direct IIC access.");
            let iic = unsafe {
                main_device
                    .get_platform_component_memory("PLATFORM_COMPONENT_SFP_NETWORK_CONTROLLER_2")
                    .context(DeviceInit)?
            };

            info!("Read status {:b}.", iic_status(iic));

            iic_enable_gpio(iic, 0x3);

            std::thread::sleep(std::time::Duration::from_millis(10));

            iic_enable_gpio(iic, 0x0);

            std::thread::sleep(std::time::Duration::from_millis(10));

            iic_write(iic, 0x74, 0x10, &[]);
            info!("Read switch {:b}.", iic_read_simple(iic, 0x74));

            iic_write(iic, 0x68, 136, &[1 << 7]);
            std::thread::sleep(std::time::Duration::from_millis(10));

            info!("Reset done.");
            // Reg 3: 0x15
            iic_write_check(iic, 0x68, 0, &[0x54, 0xE4, 0x12, 0b01010101, 0x92]);
            iic_write_check(iic, 0x68, 10, &[0x08, 0x40]);
            iic_write_check(iic, 0x68, 25, &[0xA0]);
            iic_write_check(iic, 0x68, 31, &[0x00, 0x00, 0x03]);
            iic_write_check(iic, 0x68, 40, &[0xC2, 0x49, 0xEF]);
            iic_write_check(iic, 0x68, 43, &[0x00, 0x77, 0x0B]);
            iic_write_check(iic, 0x68, 46, &[0x00, 0x77, 0x0B]);
            //iic_write(iic, 0x68, 139, &[0]);
            iic_write(iic, 0x68, 136, &[0x40]);

            iic_write(iic, 0x68, 131, &[0]);
            iic_write(iic, 0x68, 132, &[0]);

            info!("Read 131 {:b}.", iic_read(iic, 0x68, 131));
            info!("Read 132 {:b}.", iic_read(iic, 0x68, 132));
            info!("Read 134 {:b}.", iic_read(iic, 0x68, 134));
            info!("Read 135 {:b}.", iic_read(iic, 0x68, 135));
            info!("Read 136 {:b}.", iic_read(iic, 0x68, 136));

            let mut r130 = iic_read(iic, 0x68, 130);
            info!("Read 130 {:b}.", r130);
            while r130 & 1 != 0 {
                info!("Not locked...");
                iic_write(iic, 0x68, 136, &[0x40]);
                std::thread::sleep(std::time::Duration::from_millis(500));
                r130 = iic_read(iic, 0x68, 130);
            }
        }
    }

    Ok(())
}

fn main() {
    env_logger::init();

    match run() {
        Ok(_) => (),
        Err(e) => error!("ERROR: {:?}", e),
    }
}
