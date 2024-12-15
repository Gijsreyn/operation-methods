// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

use crate::DscError;
use crate::configure::context::Context;
use crate::functions::{AcceptedArgKind, Function};
use serde_json::Value;
use std::path::PathBuf;
use tracing::debug;

#[derive(Debug, Default)]
pub struct Path {}

/// Implements the `path` function.
/// Accepts a variable number of arguments, each of which is a string.
/// Returns a string that is the concatenation of the arguments, separated by the platform's path separator.
impl Function for Path {
    fn min_args(&self) -> usize {
        2
    }

    fn max_args(&self) -> usize {
        usize::MAX
    }

    fn accepted_arg_types(&self) -> Vec<AcceptedArgKind> {
        vec![AcceptedArgKind::String]
    }

    fn invoke(&self, args: &[Value], _context: &Context) -> Result<Value, DscError> {
        debug!("Executing path function with args: {:?}", args);

        let mut path = PathBuf::new();
        let mut first = true;
        for arg in args {
            if let Value::String(s) = arg {
                // if first argument is a drive letter, add it with a separator suffix as PathBuf.push() doesn't add it
                if first && s.len() == 2 && s.chars().nth(1).unwrap() == ':' {
                    path.push(s.to_owned() + std::path::MAIN_SEPARATOR.to_string().as_str());
                    first = false;
                    continue;
                } else {
                    path.push(s);
                }
            } else {
                return Err(DscError::Parser("Arguments must all be strings".to_string()));
            }
        }

        Ok(Value::String(path.to_string_lossy().to_string()))
    }
}

#[cfg(test)]
mod tests {
    use crate::configure::context::Context;
    use crate::parser::Statement;

    #[test]
    fn start_with_drive_letter() {
        let mut parser = Statement::new().unwrap();
        let separator = std::path::MAIN_SEPARATOR;
        let result = parser.parse_and_execute("[path('C:','test')]", &Context::new()).unwrap();
        assert_eq!(result, format!("C:{separator}test"));
    }

    #[test]
    fn drive_letter_in_middle() {
        let mut parser = Statement::new().unwrap();
        let separator = std::path::MAIN_SEPARATOR;
        let result = parser.parse_and_execute("[path('a','C:','test')]", &Context::new()).unwrap();
        assert_eq!(result, format!("a{separator}C:{separator}test"));
    }

    #[test]
    fn two_args() {
        let mut parser = Statement::new().unwrap();
        let separator = std::path::MAIN_SEPARATOR;
        let result = parser.parse_and_execute("[path('a','b')]", &Context::new()).unwrap();
        assert_eq!(result, format!("a{separator}b"));
    }

    #[test]
    fn three_args() {
        let mut parser = Statement::new().unwrap();
        let separator = std::path::MAIN_SEPARATOR;
        let result = parser.parse_and_execute("[path('a','b','c')]", &Context::new()).unwrap();
        assert_eq!(result, format!("a{separator}b{separator}c"));
    }
}
