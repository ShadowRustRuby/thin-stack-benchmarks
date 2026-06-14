import { Database } from "bun:sqlite";

// Open SQLite database file (placed in /app/data/music.db)
const db = new Database("/app/data/music.db");
db.run("PRAGMA busy_timeout = 10000;");
db.run("PRAGMA journal_mode = WAL;");
db.run("PRAGMA read_uncommitted = true;");

// Ensure tables exist and seed baseline data
db.run(`
    CREATE TABLE IF NOT EXISTS records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      artist TEXT,
      title TEXT,
      year TEXT,
      genre TEXT
    );
`);
db.run(`
    CREATE TABLE IF NOT EXISTS customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT
    );
`);
db.run(`
    CREATE TABLE IF NOT EXISTS likes (
      customer_id INTEGER,
      record_id INTEGER,
      FOREIGN KEY(customer_id) REFERENCES customers(id),
      FOREIGN KEY(record_id) REFERENCES records(id)
    );
`);

// Check if seeded
const countRow: any = db.query("SELECT COUNT(*) as count FROM records;").get();
if (countRow && countRow.count === 0) {
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Pink Floyd', 'The Dark Side of the Moon', '1973', 'Progressive Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Miles Davis', 'Kind of Blue', '1959', 'Jazz');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('The Beatles', 'Abbey Road', '1969', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Led Zeppelin', 'Led Zeppelin IV', '1971', 'Hard Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('John Coltrane', 'A Love Supreme', '1965', 'Jazz');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Fleetwood Mac', 'Rumours', '1977', 'Pop Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Nirvana', 'Nevermind', '1991', 'Grunge');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Marvin Gaye', 'What''s Going On', '1971', 'Soul');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('David Bowie', 'The Rise and Fall of Ziggy Stardust', '1972', 'Glam Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Radiohead', 'OK Computer', '1997', 'Alternative Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Pink Floyd', 'The Wall', '1979', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('The Beatles', 'Sgt. Pepper''s Lonely Hearts Club Band', '1967', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Michael Jackson', 'Thriller', '1982', 'Pop');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('AC/DC', 'Back in Black', '1980', 'Hard Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Nirvana', 'In Utero', '1993', 'Grunge');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Radiohead', 'Kid A', '2000', 'Electronic');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Miles Davis', 'Bitches Brew', '1970', 'Jazz');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('John Coltrane', 'Giant Steps', '1960', 'Jazz');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('David Bowie', 'Hunky Dory', '1971', 'Glam Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Bob Dylan', 'Highway 61 Revisited', '1965', 'Folk Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('The Clash', 'London Calling', '1979', 'Punk Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Queen', 'A Night at the Opera', '1975', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Prince', 'Purple Rain', '1984', 'Pop Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Bruce Springsteen', 'Born to Run', '1975', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('The Who', 'Who''s Next', '1971', 'Rock');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Bob Marley', 'Exodus', '1977', 'Reggae');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Marvin Gaye', 'Let''s Get It On', '1973', 'Soul');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Stevie Wonder', 'Songs in the Key of Life', '1976', 'Soul');");
    db.run("INSERT INTO records (artist, title, year, genre) VALUES ('Black Sabbath', 'Paranoid', '1970', 'Heavy Metal');");

    db.run("INSERT INTO customers (name, email) VALUES ('Alice Smith', 'alice@thin.dev');");
    db.run("INSERT INTO customers (name, email) VALUES ('Bob Jones', 'bob@thin.dev');");
    db.run("INSERT INTO customers (name, email) VALUES ('Charlie Brown', 'charlie@thin.dev');");

    db.run("INSERT INTO likes (customer_id, record_id) VALUES (1, 1);"); // Alice likes Pink Floyd (Dark Side)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (1, 2);"); // Alice likes Miles Davis (Kind of Blue)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (1, 11);"); // Alice likes Pink Floyd (The Wall)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (1, 13);"); // Alice likes Michael Jackson (Thriller)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (2, 2);"); // Bob likes Miles Davis (Kind of Blue)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (2, 3);"); // Bob likes The Beatles (Abbey Road)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (2, 14);"); // Bob likes AC/DC (Back in Black)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (2, 23);"); // Bob likes Queen (A Night at the Opera)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (3, 7);"); // Charlie likes Nirvana (Nevermind)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (3, 10);"); // Charlie likes Radiohead (OK Computer)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (3, 15);"); // Charlie likes Nirvana (In Utero)
    db.run("INSERT INTO likes (customer_id, record_id) VALUES (3, 16);"); // Charlie likes Radiohead (Kid A)
}

Bun.serve({
    port: 8080,
    fetch(req) {
        const url = new URL(req.url);
        if (url.pathname === '/api/records') {
            const query = url.searchParams.get('q') || '';
            const wildcard = `%${query}%`;
            
            // Execute SQLite query matching tables records, artists, genres, or liked_by customer name
            const statement = db.query(`
                SELECT r.artist, r.title, r.year, r.genre, 
                       COALESCE(GROUP_CONCAT(c.name, ', '), '') AS liked_by 
                FROM records r 
                LEFT JOIN likes l ON r.id = l.record_id 
                LEFT JOIN customers c ON l.customer_id = c.id 
                WHERE ($q = '' OR r.artist LIKE $w OR r.title LIKE $w OR r.genre LIKE $w OR c.name LIKE $w) 
                GROUP BY r.id;
            `);
            const matches = statement.all({ $q: query, $w: wildcard });
            
            return new Response(JSON.stringify(matches), {
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Connection': 'close'
                }
            });
        }
        return new Response('Not Found', { status: 404 });
    }
});

console.log("TypeScript SQLite API Server running on port 8080...");
