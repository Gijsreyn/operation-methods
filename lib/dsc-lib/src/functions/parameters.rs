// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

use crate::configure::config_doc::DataType;
use crate::configure::parameters::{SecureObject};
use crate::DscError;
use crate::configure::context::Context;
use crate::functions::{FunctionArgKind, Function, FunctionCategory, FunctionMetadata};
use rust_i18n::t;
use serde_json::Value;
use tracing::{debug, trace};

#[derive(Debug, Default)]
pub struct Parameters {}

impl Function for Parameters {
    fn get_metadata(&self) -> FunctionMetadata {
        FunctionMetadata {
            name: "parameters".to_string(),
            description: t!("functions.parameters.description").to_string(),
            category: vec![FunctionCategory::Deployment],
            min_args: 1,
            max_args: 1,
            accepted_arg_ordered_types: vec![vec![FunctionArgKind::String]],
            remaining_arg_accepted_types: None,
            return_types: vec![FunctionArgKind::String, FunctionArgKind::Number, FunctionArgKind::Boolean, FunctionArgKind::Object, FunctionArgKind::Array, FunctionArgKind::Null],
        }
    }

    fn invoke(&self, args: &[Value], context: &Context) -> Result<Value, DscError> {
        debug!("{}", t!("functions.parameters.invoked"));
        if let Some(key) = args[0].as_str() {
            trace!("{}", t!("functions.parameters.traceKey", key = key));
            if context.parameters.contains_key(key) {
                let (value, data_type) = &context.parameters[key];

                match data_type {
                    DataType::SecureString => {
                        let Some(_value) = value.as_str() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotString", key = key).to_string()));
                        };
                    },
                    DataType::SecureObject => {
                        let secure_object = SecureObject {
                            secure_object: value.clone(),
                        };
                        return Ok(serde_json::to_value(secure_object)?);
                    },
                    DataType::String => {
                        let Some(_value) = value.as_str() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotString", key = key).to_string()));
                        };
                    },
                    DataType::Int => {
                        let Some(_value) = value.as_i64() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotInt", key = key).to_string()));
                        };
                    },
                    DataType::Bool => {
                        let Some(_value) = value.as_bool() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotBool", key = key).to_string()));
                        };
                    },
                    DataType::Object => {
                        let Some(_value) = value.as_object() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotObject", key = key).to_string()));
                        };
                    },
                    DataType::Array => {
                        let Some(_value) = value.as_array() else {
                            return Err(DscError::Parser(t!("functions.parameters.keyNotArray", key = key).to_string()));
                        };
                    },
                }
                Ok(value.clone())
            }
            else {
                Err(DscError::Parser(t!("functions.parameters.keyNotFound", key = key).to_string()))
            }
        } else {
            Err(DscError::Parser(t!("functions.invalidArgType").to_string()))
        }
    }
}
