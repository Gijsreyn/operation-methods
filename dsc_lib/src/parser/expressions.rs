// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

use rust_i18n::t;
use serde_json::Value;
use tracing::{debug, trace};
use tree_sitter::Node;

use crate::configure::context::Context;
use crate::dscerror::DscError;
use crate::functions::FunctionDispatcher;
use crate::parser::functions::Function;

#[derive(Clone)]
pub enum Accessor {
    Member(String),
    Index(Value),
    IndexExpression(Expression),
}

#[derive(Clone)]
pub struct Expression {
    function: Function,
    accessors: Vec<Accessor>,
}

impl Expression {
    /// Create a new `Expression` instance.
    ///
    /// # Arguments
    ///
    /// * `function_dispatcher` - The function dispatcher to use.
    /// * `statement` - The statement that the expression is part of.
    /// * `expression` - The expression node.
    ///
    /// # Errors
    ///
    /// This function will return an error if the expression node is not valid.
    pub fn new(statement_bytes: &[u8], expression: &Node) -> Result<Self, DscError> {
        let Some(function) = expression.child_by_field_name("function") else {
            return Err(DscError::Parser(t!("parser.expression.functionNodeNotFound").to_string()));
        };
        debug!("{}", t!("parser.expression.parsingFunction", name = function : {:?}));
        let function = Function::new(statement_bytes, &function)?;
        let mut accessors = Vec::<Accessor>::new();
        if let Some(accessor) = expression.child_by_field_name("accessor") {
            debug!("{}", t!("parser.expression.parsingAccessor", name = accessor : {:?}));
            if accessor.is_error() {
                return Err(DscError::Parser(t!("parser.expression.accessorParsingError").to_string()));
            }
            let mut cursor = accessor.walk();
            for accessor in accessor.named_children(&mut cursor) {
                if accessor.is_error() {
                    return Err(DscError::Parser(t!("parser.expression.accessorParsingError").to_string()));
                }
                let accessor_kind = accessor.kind();
                let value = match accessor_kind {
                    "memberAccess" => {
                        debug!("{}", t!("parser.expression.parsingMemberAccessor", name = accessor : {:?}));
                        let Some(member_name) = accessor.child_by_field_name("name") else {
                            return Err(DscError::Parser(t!("parser.expression.memberNotFound").to_string()));
                        };
                        let member = member_name.utf8_text(statement_bytes)?;
                        Accessor::Member(member.to_string())
                    },
                    "index" => {
                        debug!("{}", t!("parser.expression.parsingIndexAccessor", index = accessor : {:?}));
                        let Some(index_value) = accessor.child_by_field_name("indexValue") else {
                            return Err(DscError::Parser(t!("parser.expression.indexNotFound").to_string()));
                        };
                        match index_value.kind() {
                            "number" => {
                                let value = index_value.utf8_text(statement_bytes)?;
                                let value = serde_json::from_str(value)?;
                                Accessor::Index(value)
                            },
                            "expression" => {
                                let expression = Expression::new(statement_bytes, &index_value)?;
                                Accessor::IndexExpression(expression)
                            },
                            _ => {
                                return Err(DscError::Parser(t!("parser.expression.invalidAccessorKind", kind = accessor_kind).to_string()));
                            },
                        }
                    },
                    _ => {
                        return Err(DscError::Parser(t!("parser.expression.invalidAccessorKind", kind = accessor_kind).to_string()));
                    },
                };
                accessors.push(value);
            }
        }

        Ok(Expression {
            function,
            accessors,
        })
    }

    /// Invoke the expression.
    ///
    /// # Arguments
    ///
    /// * `function_dispatcher` - The function dispatcher to use.
    /// * `context` - The context to use.
    ///
    /// # Returns
    ///
    /// The result of the expression.
    ///
    /// # Errors
    ///
    /// This function will return an error if the expression fails to execute.
    pub fn invoke(&self, function_dispatcher: &FunctionDispatcher, context: &Context) -> Result<Value, DscError> {
        let result = self.function.invoke(function_dispatcher, context)?;
        // skip trace if function is 'secret()'
        if self.function.name() != "secret" {
            let result_json = serde_json::to_string(&result)?;
            trace!("{}", t!("parser.expression.functionResult", results = result_json));
        }
        if self.accessors.is_empty() {
            Ok(result)
        }
        else {
            debug!("{}", t!("parser.expression.evalAccessors"));
            let mut value = result;
            for accessor in &self.accessors {
                let mut index = Value::Null;
                match accessor {
                    Accessor::Member(member) => {
                        if let Some(object) = value.as_object() {
                            if !object.contains_key(member) {
                                return Err(DscError::Parser(t!("parser.expression.memberNameNotFound", member = member).to_string()));
                            }
                            value = object[member].clone();
                        } else {
                            return Err(DscError::Parser(t!("parser.expression.accessOnNonObject").to_string()));
                        }
                    },
                    Accessor::Index(index_value) => {
                        index = index_value.clone();
                    },
                    Accessor::IndexExpression(expression) => {
                        index = expression.invoke(function_dispatcher, context)?;
                        trace!("{}", t!("parser.expression.expressionResult", index = index : {:?}));
                    },
                }

                if index.is_number() {
                    if let Some(array) = value.as_array() {
                        let Some(index) = index.as_u64() else {
                            return Err(DscError::Parser(t!("parser.expression.indexNotValid").to_string()));
                        };
                        let index = usize::try_from(index)?;
                        if index >= array.len() {
                            return Err(DscError::Parser(t!("parser.expression.indexOutOfBounds").to_string()));
                        }
                        value = array[index].clone();
                    } else {
                        return Err(DscError::Parser(t!("parser.expression.indexOnNonArray").to_string()));
                    }
                }
                else if !index.is_null() {
                    return Err(DscError::Parser(t!("parser.expression.invalidIndexType").to_string()));
                }
            }

            Ok(value)
        }
    }
}
