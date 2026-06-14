use serde::Serialize;
use std::fs;
use tiny_http::{Response, Server};

#[derive(Serialize, Clone)]
struct Record {
    artist: String,
    title: String,
    year: String,
    genre: String,
}

fn main() {
    // Load CSV file
    let csv_path = "../../data/records.csv";
    let csv_data = match fs::read_to_string(csv_path) {
        Ok(data) => data,
        Err(e) => {
            eprintln!("Failed to read CSV from {}: {}", csv_path, e);
            std::process::exit(1);
        }
    };

    let mut records = Vec::new();
    let lines: Vec<&str> = csv_data.split('\n').collect();
    // Skip header
    for line in lines.iter().skip(1) {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let parts: Vec<&str> = trimmed.split(',').collect();
        if parts.len() >= 4 {
            records.push(Record {
                artist: parts[0].to_string(),
                title: parts[1].to_string(),
                year: parts[2].to_string(),
                genre: parts[3].to_string(),
            });
        }
    }

    let server = Server::http("0.0.0.0:8080").unwrap();
    println!("Rust API Server running on port 8080...");

    for request in server.incoming_requests() {
        let url = request.url();
        if url.starts_with("/api/records") {
            // Parse query param ?q=
            let query = if let Some(pos) = url.find("?q=") {
                let q_val = &url[pos + 3..];
                // strip anything after & or space
                let end = q_val.find('&').unwrap_or(q_val.len());
                let raw_query = &q_val[..end];
                // decode url-encoded query if necessary, but keep it simple for benchmarks:
                // replace %20 with space
                raw_query.replace("%20", " ").to_lowercase()
            } else {
                String::new()
            };

            let matches: Vec<Record> = records
                .iter()
                .filter(|r| {
                    query.is_empty()
                        || r.artist.to_lowercase().contains(&query)
                        || r.title.to_lowercase().contains(&query)
                        || r.genre.to_lowercase().contains(&query)
                })
                .cloned()
                .collect();

            let json_response = serde_json::to_string(&matches).unwrap();
            let response = Response::from_string(json_response)
                .with_header(tiny_http::Header::from_bytes(&b"Content-Type"[..], &b"application/json"[..]).unwrap())
                .with_header(tiny_http::Header::from_bytes(&b"Access-Control-Allow-Origin"[..], &b"*"[..]).unwrap())
                .with_header(tiny_http::Header::from_bytes(&b"Connection"[..], &b"close"[..]).unwrap());
            let _ = request.respond(response);
        } else {
            let response = Response::from_string("Not Found")
                .with_status_code(404);
            let _ = request.respond(response);
        }
    }
}
