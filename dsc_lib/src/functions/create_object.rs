// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

use crate::DscError;
use crate::configure::context::Context;
use crate::functions::{AcceptedArgKind, Function, FunctionCategory};
use rust_i18n::t;
use serde_json::{Map, Value};
use tracing::debug;

#[derive(Debug, Default)]
pub struct CreateObject {}

impl Function for CreateObject {
    fn description(&self) -> String {
        t!("functions.createObject.description").to_string()
    }

    fn category(&self) -> FunctionCategory {
        FunctionCategory::Object
    }

    fn min_args(&self) -> usize {
        0
    }

    fn max_args(&self) -> usize {
        usize::MAX
    }

    fn accepted_arg_types(&self) -> Vec<AcceptedArgKind> {
        vec![
            AcceptedArgKind::Array,
            AcceptedArgKind::Boolean,
            AcceptedArgKind::Number,
            AcceptedArgKind::Object,
            AcceptedArgKind::String,
        ]
    }

    fn invoke(&self, args: &[Value], _context: &Context) -> Result<Value, DscError> {
        debug!("{}", t!("functions.createObject.invoked"));
        
        if args.len() % 2 != 0 {
            return Err(DscError::Parser(t!("functions.createObject.argsMustBePairs").to_string()));
        }

        let mut object_result = Map::<String, Value>::new();
        
        for chunk in args.chunks(2) {
            let key = &chunk[0];
            let value = &chunk[1];
            
            if !key.is_string() {
                return Err(DscError::Parser(t!("functions.createObject.keyMustBeString").to_string()));
            }
            
            let key_str = key.as_str().unwrap().to_string();
            object_result.insert(key_str, value.clone());
        }

        Ok(Value::Object(object_result))
    }
}

#[cfg(test)]
mod tests {
    use crate::configure::context::Context;
    use crate::parser::Statement;

    #[test]
    fn simple_object() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('name', 'test')]", &Context::new()).unwrap();
        assert_eq!(result.to_string(), r#"{"name":"test"}"#);
    }

    #[test]
    fn multiple_properties() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('name', 'test', 'value', 42)]", &Context::new()).unwrap();
        assert_eq!(result.to_string(), r#"{"name":"test","value":42}"#);
    }

    #[test]
    fn mixed_value_types() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('string', 'hello', 'number', 123, 'boolean', true)]", &Context::new()).unwrap();
        
        let json: serde_json::Value = serde_json::from_str(&result.to_string()).unwrap();
        assert_eq!(json["string"], "hello");
        assert_eq!(json["number"], 123);
        assert_eq!(json["boolean"], true);
    }

    #[test]
    fn nested_objects() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('outer', createObject('inner', 'value'))]", &Context::new()).unwrap();
        assert_eq!(result.to_string(), r#"{"outer":{"inner":"value"}}"#);
    }

    #[test]
    fn with_arrays() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('items', createArray('a', 'b', 'c'))]", &Context::new()).unwrap();
        assert_eq!(result.to_string(), r#"{"items":["a","b","c"]}"#);
    }

    #[test]
    fn odd_number_of_args() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject('name')]", &Context::new());
        assert!(result.is_err());
    }

    #[test]
    fn non_string_key() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject(123, 'value')]", &Context::new());
        assert!(result.is_err());
    }

    #[test]
    fn empty() {
        let mut parser = Statement::new().unwrap();
        let result = parser.parse_and_execute("[createObject()]", &Context::new()).unwrap();
        assert_eq!(result.to_string(), "{}");
    }
}
