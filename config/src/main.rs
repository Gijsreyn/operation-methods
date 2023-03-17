use args::*;
use atty::Stream;
use clap::Parser;
use dsc_lib::{DscManager, dscresources::dscresource::{DscResource, Invoke}};
use std::io::{self, Read};
use std::process::exit;
use syntect::easy::HighlightLines;
use syntect::parsing::SyntaxSet;
use syntect::highlighting::{ThemeSet, Style};
use syntect::util::{as_24_bit_terminal_escaped, LinesWithEndings};

#[cfg(debug_assertions)]
use crossterm::event;
#[cfg(debug_assertions)]
use std::env;

pub mod args;

const EXIT_SUCCESS: i32 = 0;
const EXIT_INVALID_ARGS: i32 = 1;
const EXIT_DSC_ERROR: i32 = 2;
const EXIT_JSON_ERROR: i32 = 3;

fn main() {
    #[cfg(debug_assertions)]
    check_debug();

    let args = Args::parse();

    let stdin: Option<String> = if atty::is(Stream::Stdin) {
        None
    } else {
        let mut buffer: Vec<u8> = Vec::new();
        io::stdin().read_to_end(&mut buffer).unwrap();
        let input = match String::from_utf8(buffer) {
            Ok(input) => input,
            Err(e) => {
                eprintln!("Invalid UTF-8 sequence: {}", e);
                exit(EXIT_INVALID_ARGS);
            },
        };
        Some(input)
    };

    let mut dsc = match DscManager::new() {
        Ok(dsc) => dsc,
        Err(err) => {
            eprintln!("Error: {}", err);
            exit(EXIT_DSC_ERROR);
        }
    };

    match args.subcommand {
        SubCommand::List { resource_name } => {
            match dsc.initialize_discovery() {
                Ok(_) => (),
                Err(err) => {
                    eprintln!("Error: {}", err);
                    exit(EXIT_DSC_ERROR);
                }
            };
            for resource in dsc.find_resource(&resource_name.unwrap_or_default()) {
                // convert to json
                let json = match serde_json::to_string(&resource) {
                    Ok(json) => json,
                    Err(err) => {
                        eprintln!("JSON Error: {}", err);
                        exit(EXIT_JSON_ERROR);
                    }
                };
                write_output(&json, &args.format);
                println!("");
            }
        }
        SubCommand::Get { resource, input } => {
            // TODO: support streaming stdin which includes resource and input

            let input = get_input(&input, &stdin);
            let resource = get_resource(&mut dsc, resource.as_str());
            match resource.get(input.as_str()) {
                Ok(result) => {
                    // convert to json
                    let json = match serde_json::to_string(&result) {
                        Ok(json) => json,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    };
                    write_output(&json, &args.format);
                }
                Err(err) => {
                    eprintln!("Error: {}", err);
                    exit(EXIT_DSC_ERROR);
                }
            }
        }
        SubCommand::Set { resource, input: _ } => {
            let input = get_input(&None, &stdin);
            let resource = get_resource(&mut dsc, resource.as_str());
            match resource.set(input.as_str()) {
                Ok(result) => {
                    // convert to json
                    let json = match serde_json::to_string(&result) {
                        Ok(json) => json,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    };
                    write_output(&json, &args.format);
                }
                Err(err) => {
                    eprintln!("Error: {}", err);
                    exit(EXIT_DSC_ERROR);
                }
            }
        }
        SubCommand::Test { resource, input: _ } => {
            let input = get_input(&None, &stdin);
            let resource = get_resource(&mut dsc, resource.as_str());
            match resource.test(input.as_str()) {
                Ok(result) => {
                    // convert to json
                    let json = match serde_json::to_string(&result) {
                        Ok(json) => json,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    };
                    write_output(&json, &args.format);
                }
                Err(err) => {
                    eprintln!("Error: {}", err);
                    exit(EXIT_DSC_ERROR);
                }
            }
        }
    }

    exit(EXIT_SUCCESS);
}

fn write_output(json: &str, format: &Option<OutputFormat>) {
    let mut is_json = true;
    match atty::is(Stream::Stdout) {
        true => {
            let output = match format {
                Some(OutputFormat::Json) => json.to_string(),
                Some(OutputFormat::PrettyJson) => {
                    let value: serde_json::Value = match serde_json::from_str(json) {
                        Ok(value) => value,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    };
                    match serde_json::to_string_pretty(&value) {
                        Ok(json) => json,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    }
                },
                Some(OutputFormat::Yaml) | None => {
                    is_json = false;
                    let value: serde_json::Value = match serde_json::from_str(json) {
                        Ok(value) => value,
                        Err(err) => {
                            eprintln!("JSON Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    };
                    match serde_yaml::to_string(&value) {
                        Ok(yaml) => yaml,
                        Err(err) => {
                            eprintln!("YAML Error: {}", err);
                            exit(EXIT_JSON_ERROR);
                        }
                    }
                }
            };

            let ps = SyntaxSet::load_defaults_newlines();
            let ts = ThemeSet::load_defaults();
            let syntax = match is_json {
                true => ps.find_syntax_by_extension("json").unwrap(),
                false => ps.find_syntax_by_extension("yaml").unwrap(),
            };
    
            let mut h = HighlightLines::new(syntax, &ts.themes["base16-ocean.dark"]);
    
            for line in LinesWithEndings::from(&output) {
                let ranges: Vec<(Style, &str)> = h.highlight_line(line, &ps).unwrap();
                let escaped = as_24_bit_terminal_escaped(&ranges[..], true);
                print!("{}", escaped);
            }
        },
        false => {
            println!("{}", json);
        }
    };
}

fn get_resource(dsc: &mut DscManager, resource: &str) -> DscResource {
    // check if resource is JSON or just a name
    match serde_json::from_str(resource) {
        Ok(resource) => resource,
        Err(err) => {
            if resource.contains('{') {
                eprintln!("Not valid resource JSON: {}\nInput was: {}", err, resource);
                exit(EXIT_INVALID_ARGS);
            }

            match dsc.initialize_discovery() {
                Ok(_) => (),
                Err(err) => {
                    eprintln!("Error: {}", err);
                    exit(EXIT_DSC_ERROR);
                }
            };
            let resources: Vec<DscResource> = dsc.find_resource(resource).collect();
            match resources.len() {
                0 => {
                    eprintln!("Error: Resource not found");
                    exit(EXIT_INVALID_ARGS);
                }
                1 => resources[0].clone(),
                _ => {
                    eprintln!("Error: Multiple resources found");
                    exit(EXIT_INVALID_ARGS);
                }
            }
        }
    }
}

fn get_input(input: &Option<String>, stdin: &Option<String>) -> String {
    let input = match (input, stdin) {
        (Some(_input), Some(_stdin)) => {
            eprintln!("Error: Cannot specify both --input and stdin");
            exit(EXIT_INVALID_ARGS);
        }
        (Some(input), None) => input.clone(),
        (None, Some(stdin)) => stdin.clone(),
        (None, None) => {
            eprintln!("Error: No input specified");
            exit(EXIT_INVALID_ARGS);
        },
    };

    match serde_json::from_str::<serde_json::Value>(&input) {
        Ok(_) => input,
        Err(json_err) => {
            match serde_yaml::from_str::<serde_yaml::Value>(&input) {
                Ok(yaml) => {
                    match serde_json::to_string(&yaml) {
                        Ok(json) => json,
                        Err(err) => {
                            eprintln!("Error: Cannot convert YAML to JSON: {}", err);
                            exit(EXIT_INVALID_ARGS);
                        }
                    }
                },
                Err(err) => {
                    if input.contains('{') {
                        eprintln!("Error: Input is not valid JSON: {}", json_err);
                    }
                    else {
                        eprintln!("Error: Input is not valid YAML: {}", err);
                    }
                    exit(EXIT_INVALID_ARGS);
                }
            }
        }
    }
}

#[cfg(debug_assertions)]
fn check_debug() {
    if env::var("DEBUG_CONFIG").is_ok() {
        eprintln!("attach debugger to pid {} and press any key to continue", std::process::id());
        loop {
            let event = event::read().unwrap();
            match event {
                event::Event::Key(_key) => {
                    break;
                }
                _ => {
                    eprintln!("Unexpected event: {:?}", event);
                    continue;
                }
            }
        }
    }
}
