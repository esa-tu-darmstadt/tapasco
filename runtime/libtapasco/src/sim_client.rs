use std::cmp::min;
use std::io;
use std::sync::Mutex;
use snafu::ResultExt;
use tokio::runtime::{Builder, Runtime};
use crate::protos::simcalls::{
    InterruptStatusRequest,
    Void,
    SimResponseType,
    RegisterInterrupt,
    DeregisterInterrupt,
    WriteMemory,
    ReadMemory,
    WritePlatform,
    ReadPlatform,
    sim_request_client::SimRequestClient,
    sim_response::ResponsePayload
};
use crate::protos::status;
use crate::sim_client::Error::*;
use std::env;


#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Failed to build tokio runtime: {}", source))]
    TonicRuntimeBuild { source: io::Error },

    #[snafu(display("Failed to acquire lock on client mutex"))]
    ClientLockError { },

    #[snafu(display("Failed to connect to gRPC server: {}", source))]
    Connect { source: tonic::transport::Error },

    #[snafu(display("Failed to connect to gRPC server: {}", source))]
    Request { source: tonic::Status },

    #[snafu(display("Server Error: {}", message))]
    ServerError { message: String },

    #[snafu(display("Got wrong payload from request: {:?}, expected {}", payload, expected))]
    WrongResponsePayload { payload: ResponsePayload, expected: String },

    #[snafu(display("Got payload None, expected {:?}", expected))]
    ResponseNone { expected: String},

    #[snafu(display("ResponseType is None or unsupported: {:?}", t))]
    ResponseType { t:  Option<SimResponseType>},

    #[snafu(display("Error processing read/write memory request"))]
    MemForEachError { },

    #[snafu(whatever, display("{}", message))]
    Whatever {
        message: String,
        #[snafu(source(from(Box<dyn std::error::Error>, Some)))]
        source: Option<Box<dyn std::error::Error>>
    }
}
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Debug)]
pub struct SimClient {
    client: Mutex<SimRequestClient<tonic::transport::Channel>>,
    rt: Runtime,
}

impl SimClient {
    pub fn new() -> Result<Self> {
        let rt = Builder::new_multi_thread().enable_all().build().context(TonicRuntimeBuildSnafu)?;
        let port = match env::var("SIM_PORT") {
            Ok(p) => whatever!(p.parse::<u32>(), "Error parsing SIM_PORT"),
            Err(_) => 4040,
        };
        let client = rt.block_on(SimRequestClient::connect(format!("http://[::1]:{}", port))).context(ConnectSnafu)?;

        Ok(Self {
            client: Mutex::new(client),
            rt,
        })
    }

    pub fn write_platform(&self, write_platform: WritePlatform) -> Result<Void> {
        trace!("write platform: {write_platform:?}");
        let request = tonic::Request::new(write_platform);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.write_platform(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "Void".to_string()}),
                None => Err(ResponseNone {expected: "Void".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }


    pub fn read_platform(&self, read_platform: ReadPlatform) -> Result<Vec<u32>> {
        let num_bytes = read_platform.num_bytes;
        let request = tonic::Request::new(read_platform);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.read_platform(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        let range = match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::ReadPlatformResponse(response)) => Ok(response.value),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ReadPlatformResponse".to_string()}),
                None => Err(ResponseNone {expected: "ReadPlatformResponse".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }?;
        if range.len() as u32 != num_bytes {
            whatever!("Mismatch of requested and delivered number of bytes")
        } else {
            Ok(range)
        }
    }

    pub fn read_memory(&self, read_memory: ReadMemory) -> Result<Vec<u32>> {
        let max_chunk_size = 2097152_u64;
        let mut read_mem: Vec<u32> = Vec::with_capacity(read_memory.length as usize);

        let mut bytes_left = read_memory.length;
        let mut curr_offset = 0;

        while bytes_left > 0 {
            let bytes_to_read = min(bytes_left, max_chunk_size);
            let _read_memory = ReadMemory {
                addr: (curr_offset * max_chunk_size) as u64,
                length: bytes_to_read,
            };
            read_mem.extend(self._read_memory(_read_memory)?);
            bytes_left -= bytes_to_read;
            curr_offset += 1;
        }

        Ok(read_mem)
    }

    fn _read_memory(&self, read_memory: ReadMemory) -> Result<Vec<u32>> {
        trace!("read memory len: {}", read_memory.length);
        let request = tonic::Request::new(read_memory);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.read_memory(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::ReadMemoryResponse(response)) => Ok(response.value),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ReadMemoryResponse".to_string()}),
                None => Err(ResponseNone {expected: "ReadMemoryResponse".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }

    pub fn write_memory(&self, write_memory: WriteMemory) -> Result<Void> {
        let max_chunk_size = 2097152;
        let chunks: Vec<&[u32]> = write_memory.data.chunks(max_chunk_size).collect();
        chunks.iter().enumerate().try_for_each(|(idx, chunk)| -> Result<()> {
            let _write_memory = WriteMemory {
                addr: (idx * max_chunk_size) as u64,
                data: chunk.to_vec(),
            };
            self._write_memory(_write_memory).unwrap();
            Ok(())
        }).map(|_| Void{})        
    }

    fn _write_memory(&self, write_memory: WriteMemory) -> Result<Void> {
        trace!("write memory len: {}", write_memory.data.len());
        let request = tonic::Request::new(write_memory);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.write_memory(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "Void".to_string()}),
                None => Err(ResponseNone {expected: "Void".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }

    pub fn register_interrupt(&self, register_interrupt: RegisterInterrupt) -> Result<Void> {
        let request = tonic::Request::new(register_interrupt);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.register_interrupt(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "Void".to_string()}),
                None => Err(ResponseNone {expected: "Void".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }

    pub fn deregister_interrupt(&self, register_interrupt: DeregisterInterrupt) -> Result<Void> {
        let request = tonic::Request::new(register_interrupt);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.deregister_interrupt(request)).context(RequestSnafu)?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "Void".to_string()}),
                None => Err(ResponseNone {expected: "Void".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }

    pub fn get_status(&self) -> Result<status::Status> {
        let request = tonic::Request::new(Void{});
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.get_status(request)).context(RequestSnafu)?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Status(status)) => Ok(status),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "Status".to_string()}),
                None => Err(ResponseNone {expected: "Status".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }

    pub fn get_interrupt_status(&self, interrupt_status_request: InterruptStatusRequest) -> Result<u64> {
        let request = tonic::Request::new(interrupt_status_request);
        let mut client = self.client.lock().map_err(|_| ClientLockError {})?;
        let response = self.rt.block_on(client.get_interrupt_status(request)).context(RequestSnafu)?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::InterruptStatus(status)) => Ok(status.interrupts),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "InterruptStatus".to_string()}),
                None => Err(ResponseNone {expected: "InterruptStatus".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(ServerError {message: reason}),
                Some(r) => Err(WrongResponsePayload {payload: r, expected: "ErrorReason".to_string()}),
                _ => Err(ResponseNone {expected: "ErrorReason".to_string()}),
            },
            x => Err(ResponseType {t: x})
        }
    }
}