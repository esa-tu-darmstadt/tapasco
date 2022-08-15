use std::borrow::BorrowMut;
use std::sync::Mutex;
use nix::dir::Type;
use tokio::runtime::{Builder, Runtime};
use crate::device;
use crate::device::Error::SimError;
use device::simcalls::{
    InterruptStatusRequest,
    InterruptStatus,
    Void,
    SimResponseType,
    RegisterInterrupt,
    DeregisterInterrupt,
    StartPe,
    SetArg,
    sim_request_client::SimRequestClient,
    sim_response::ResponsePayload
};
use crate::device::status::Status;

#[derive(Debug)]
pub struct SimClient {
    client: Mutex<SimRequestClient<tonic::transport::Channel>>,
    rt: Runtime,
}

impl SimClient {
    pub fn new() -> Result<Self, device::Error> {
        let rt = Builder::new_multi_thread().enable_all().build().map_err(|_| SimError { message: String::from("Error creating runtime") })?;
        let mut client = rt.block_on(SimRequestClient::connect("http://[::1]:4040")).map_err(|_| SimError { message: String::from("Error connecting to gRPC server") })?;

        Ok(Self {
            client: Mutex::new(client),
            rt,
        })
    }

    pub fn register_interrupt(&self, register_interrupt: RegisterInterrupt) -> Result<Void, device::Error> {
        let request = tonic::Request::new(register_interrupt);
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error locking client".to_string()})?;
        let response = self.rt.block_on(client.register_interrupt(request)).map_err(|_| SimError {message: String::from("Error requesting interrupt")})?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }

    pub fn deregister_interrupt(&self, register_interrupt: DeregisterInterrupt) -> Result<Void, device::Error> {
        let request = tonic::Request::new(register_interrupt);
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error locking client".to_string()})?;
        let response = self.rt.block_on(client.deregister_interrupt(request)).map_err(|_| SimError {message: String::from("Error deregistering interrupt")})?;

        let inner = response.into_inner();
        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(r) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }

    pub fn get_status(&self) -> Result<device::status::Status, device::Error> {
        let request = tonic::Request::new(Void{});
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error locking client".to_string()})?;
        let response = self.rt.block_on(client.get_status(request)).map_err(|err| {
            println!("{:?}", err); SimError {message: String::from("Error requesting status")}})?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Status(status)) => Ok(status),
                Some(r) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }

    pub fn get_interrupt_status(&self, interrupt_status_request: InterruptStatusRequest) -> Result<u64, device::Error> {
        let request = tonic::Request::new(interrupt_status_request);
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error locking client".to_string()})?;
        let response = self.rt.block_on(client.get_interrupt_status(request)).map_err(|_| SimError {message: "Error getting interrupt status".to_string()})?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::InterruptStatus(status)) => Ok(status.interrupts),
                Some(r) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }

    pub fn start_pe(&self, start_pe: StartPe) -> Result<Void, device::Error> {
        let request = tonic::Request::new(start_pe);
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error getting client mutext".to_string()})?;
        let response = self.rt.block_on(client.start_pe(request)).map_err(|_| SimError {message: "Error sending start_pe rpc".to_string()})?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(_) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }

    pub fn set_arg(&self, set_arg: SetArg) -> Result<Void, device::Error> {
        let request = tonic::Request::new(set_arg);
        let mut client = self.client.lock().map_err(|_| SimError {message: "Error getting client mutext".to_string()})?;
        let response = self.rt.block_on(client.set_arg(request)).map_err(|_| SimError {message: "Error sending set_arg rpc".to_string()})?;
        let inner = response.into_inner();

        match SimResponseType::from_i32(inner.r#type) {
            Some(SimResponseType::Okay) => match inner.response_payload {
                Some(ResponsePayload::Void(void)) => Ok(void),
                Some(_) => Err(SimError {message: "Got wrong payload from request".to_string()}),
                None => Err(SimError {message: "response payload is None".to_string()}),
            },
            Some(SimResponseType::Error) => match inner.response_payload {
                Some(ResponsePayload::ErrorReason(reason)) => Err(SimError {message: reason}),
                _ => Err(SimError {message: "Got Error SimResponse, but payload not ErrorReason".to_string()})
            },
            x =>  Err(SimError {message: format!("Unknown SimResponseType: {:?}", x).to_string()})
        }
    }
}