use std::env;
use std::fs;
use std::collections::HashMap;
use w3strings::{decode, encode, hash_key};

// Minimal CLI: encode/decode w3strings CSV <-> binary for the infusion mod.
// Usage:
//   strings-cli encode <input.csv> <output.w3strings>
//   strings-cli decode <input.w3strings> <output.csv> [keys.txt]
//
// CSV format (pipe-separated, per w3strings crate docs):
//   ;meta[language=en]
//   ; id | key(hex) | key(str) | text
//   123456||option_MyKey|My text
fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 4 {
        eprintln!("usage: strings-cli encode <in.csv> <out.w3strings> | decode <in.w3strings> <out.csv> [keys.txt]");
        std::process::exit(1);
    }

    let mode = &args[1];
    match mode.as_str() {
        "encode" => {
            let csv = fs::read_to_string(&args[2]).expect("read csv");
            let binary = encode(&csv).expect("encode");
            fs::write(&args[3], binary).expect("write output");
            println!("encoded {} -> {}", args[2], args[3]);
        }
        "decode" => {
            let binary = fs::read(&args[2]).expect("read w3strings");
            let mut dict: HashMap<u32, String> = HashMap::new();
            if args.len() > 4 {
                let keys = fs::read_to_string(&args[4]).expect("read keys");
                for line in keys.lines() {
                    let k = line.trim();
                    if !k.is_empty() {
                        dict.insert(hash_key(k), k.to_string());
                    }
                }
            }
            let csv = decode(&binary, &dict).expect("decode");
            fs::write(&args[3], csv).expect("write output");
            println!("decoded {} -> {}", args[2], args[3]);
        }
        _ => {
            eprintln!("unknown mode: {}", mode);
            std::process::exit(1);
        }
    }
}
