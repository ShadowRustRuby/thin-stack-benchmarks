use rusqlite::{params, Connection, Result};
use serde::Serialize;
use tiny_http::{Response, Header, Server};

#[derive(Serialize)]
struct SQLRecord {
    artist: String,
    title: String,
    year: String,
    genre: String,
    liked_by: String,
}

fn init_db() -> Result<Connection> {
    let conn = Connection::open("/app/data/music.db")?;
    
    // Set configuration pragmas
    conn.pragma_update(None, "busy_timeout", &10000)?;
    conn.pragma_update(None, "journal_mode", &"WAL")?;
    conn.pragma_update(None, "read_uncommitted", &true)?;

    // Create tables
    conn.execute(
        "CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            artist TEXT,
            title TEXT,
            year TEXT,
            genre TEXT
        );",
        [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT
        );",
        [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS likes (
            customer_id INTEGER,
            record_id INTEGER,
            FOREIGN KEY(customer_id) REFERENCES customers(id),
            FOREIGN KEY(record_id) REFERENCES records(id)
        );",
        [],
    )?;

    // Check if seeding is needed
    let count: i64 = conn.query_row("SELECT COUNT(*) FROM records;", [], |row| row.get(0))?;
    if count == 0 {
        let records = vec![
            ("Pink Floyd", "The Dark Side of the Moon", "1973", "Progressive Rock"),
            ("Miles Davis", "Kind of Blue", "1959", "Jazz"),
            ("The Beatles", "Abbey Road", "1969", "Rock"),
            ("Led Zeppelin", "Led Zeppelin IV", "1971", "Hard Rock"),
            ("John Coltrane", "A Love Supreme", "1965", "Jazz"),
            ("Fleetwood Mac", "Rumours", "1977", "Pop Rock"),
            ("Nirvana", "Nevermind", "1991", "Grunge"),
            ("Marvin Gaye", "What's Going On", "1971", "Soul"),
            ("David Bowie", "The Rise and Fall of Ziggy Stardust", "1972", "Glam Rock"),
            ("Radiohead", "OK Computer", "1997", "Alternative Rock"),
            ("Pink Floyd", "The Wall", "1979", "Rock"),
            ("The Beatles", "Sgt. Pepper's Lonely Hearts Club Band", "1967", "Rock"),
            ("Michael Jackson", "Thriller", "1982", "Pop"),
            ("AC/DC", "Back in Black", "1980", "Hard Rock"),
            ("Nirvana", "In Utero", "1993", "Grunge"),
            ("Radiohead", "Kid A", "2000", "Electronic"),
            ("Miles Davis", "Bitches Brew", "1970", "Jazz"),
            ("John Coltrane", "Giant Steps", "1960", "Jazz"),
            ("David Bowie", "Hunky Dory", "1971", "Glam Rock"),
            ("Bob Dylan", "Highway 61 Revisited", "1965", "Folk Rock"),
            ("The Clash", "London Calling", "1979", "Punk Rock"),
            ("Queen", "A Night at the Opera", "1975", "Rock"),
            ("Prince", "Purple Rain", "1984", "Pop Rock"),
            ("Bruce Springsteen", "Born to Run", "1975", "Rock"),
            ("The Who", "Who's Next", "1971", "Rock"),
            ("Bob Marley", "Exodus", "1977", "Reggae"),
            ("Marvin Gaye", "Let's Get It On", "1973", "Soul"),
            ("Stevie Wonder", "Songs in the Key of Life", "1976", "Soul"),
            ("Black Sabbath", "Paranoid", "1970", "Heavy Metal"),
        ];

        for r in records {
            conn.execute(
                "INSERT INTO records (artist, title, year, genre) VALUES (?1, ?2, ?3, ?4);",
                params![r.0, r.1, r.2, r.3],
            )?;
        }

        let customers = vec![
            ("Alice Smith", "alice@thin.dev"),
            ("Bob Jones", "bob@thin.dev"),
            ("Charlie Brown", "charlie@thin.dev"),
        ];

        for c in customers {
            conn.execute(
                "INSERT INTO customers (name, email) VALUES (?1, ?2);",
                params![c.0, c.1],
            )?;
        }

        let likes = vec![
            (1, 1), (1, 2), (1, 11), (1, 13),
            (2, 2), (2, 3), (2, 14), (2, 23),
            (3, 7), (3, 10), (3, 15), (3, 16),
        ];

        for l in likes {
            conn.execute(
                "INSERT INTO likes (customer_id, record_id) VALUES (?1, ?2);",
                params![l.0, l.1],
            )?;
        }
    }

    Ok(conn)
}

fn main() {
    let conn = match init_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Database initialization failed: {}", e);
            std::process::exit(1);
        }
    };

    let server = Server::http("0.0.0.0:8080").unwrap();
    println!("Rust SQLite API Server running on port 8080...");

    for request in server.incoming_requests() {
        let url = request.url();
        if url.starts_with("/api/records") {
            // Parse query param ?q=
            let query = if let Some(pos) = url.find("?q=") {
                let q_val = &url[pos + 3..];
                let end = q_val.find('&').unwrap_or(q_val.len());
                let raw_query = &q_val[..end];
                raw_query.replace("%20", " ")
            } else {
                String::new()
            };

            let wildcard = format!("%{}%", query);

            let mut stmt = match conn.prepare(
                "SELECT r.artist, r.title, r.year, r.genre, 
                        COALESCE(GROUP_CONCAT(c.name, ', '), '') AS liked_by 
                 FROM records r 
                 LEFT JOIN likes l ON r.id = l.record_id 
                 LEFT JOIN customers c ON l.customer_id = c.id 
                 WHERE (?1 = '' OR r.artist LIKE ?2 OR r.title LIKE ?2 OR r.genre LIKE ?2 OR c.name LIKE ?2) 
                 GROUP BY r.id;"
            ) {
                Ok(s) => s,
                Err(e) => {
                    let response = Response::from_string(format!("Query prep error: {}", e))
                        .with_status_code(500);
                    let _ = request.respond(response);
                    continue;
                }
            };

            let rows_iter = match stmt.query_map(params![query, wildcard], |row| {
                Ok(SQLRecord {
                    artist: row.get(0)?,
                    title: row.get(1)?,
                    year: row.get(2)?,
                    genre: row.get(3)?,
                    liked_by: row.get(4)?,
                })
            }) {
                Ok(r) => r,
                Err(e) => {
                    let response = Response::from_string(format!("Query exec error: {}", e))
                        .with_status_code(500);
                    let _ = request.respond(response);
                    continue;
                }
            };

            let mut matches = Vec::new();
            for r_res in rows_iter {
                if let Ok(record) = r_res {
                    matches.push(record);
                }
            }

            let json_response = serde_json::to_string(&matches).unwrap();
            let response = Response::from_string(json_response)
                .with_header(Header::from_bytes(&b"Content-Type"[..], &b"application/json"[..]).unwrap())
                .with_header(Header::from_bytes(&b"Access-Control-Allow-Origin"[..], &b"*"[..]).unwrap())
                .with_header(Header::from_bytes(&b"Connection"[..], &b"close"[..]).unwrap());
            let _ = request.respond(response);
        } else {
            let response = Response::from_string("Not Found")
                .with_status_code(404);
            let _ = request.respond(response);
        }
    }
}
