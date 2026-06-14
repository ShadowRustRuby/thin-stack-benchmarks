#include <sqlite3.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

extern "C" {

// Persistent global SQLite connection pointer
sqlite3 *global_db = NULL;

// In-place helper to decode URL percent encoding
void url_decode_db(char *dst, const char *src) {
    char a, b;
    while (*src) {
        if ((*src == '%') &&
            ((a = src[1]) && (b = src[2])) &&
            (isxdigit((unsigned char)a) && isxdigit((unsigned char)b))) {
            if (a >= 'a') a -= 'a'-'A';
            if (a >= 'A') a -= ('A' - 10);
            else a -= '0';
            if (b >= 'a') b -= 'a'-'A';
            if (b >= 'A') b -= ('A' - 10);
            else b -= '0';
            *dst++ = 16*a+b;
            src += 3;
        } else if (*src == '+') {
            *dst++ = ' ';
            src++;
        } else {
            *dst++ = *src++;
        }
    }
    *dst = '\0';
}

void init_db_schema() {
    if (global_db) return; // Connection already initialized and persistent

    int rc = sqlite3_open("/app/data/music.db", &global_db);
    if (rc != SQLITE_OK) {
        sqlite3_close(global_db);
        global_db = NULL;
        return;
    }

    // Set configuration pragmas on global DB pointer
    sqlite3_busy_timeout(global_db, 10000); // Wait up to 10 seconds for locks to clear
    sqlite3_exec(global_db, "PRAGMA journal_mode = WAL;", 0, 0, 0);
    sqlite3_exec(global_db, "PRAGMA read_uncommitted = true;", 0, 0, 0);

    const char *sql_schema = 
        "CREATE TABLE IF NOT EXISTS records ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  artist TEXT,"
        "  title TEXT,"
        "  year TEXT,"
        "  genre TEXT"
        ");"
        "CREATE TABLE IF NOT EXISTS customers ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT,"
        "  email TEXT"
        ");"
        "CREATE TABLE IF NOT EXISTS likes ("
        "  customer_id INTEGER,"
        "  record_id INTEGER,"
        "  FOREIGN KEY(customer_id) REFERENCES customers(id),"
        "  FOREIGN KEY(record_id) REFERENCES records(id)"
        ");";

    sqlite3_exec(global_db, sql_schema, 0, 0, 0);

    // Seed tables if records are empty
    sqlite3_stmt *stmt;
    sqlite3_prepare_v2(global_db, "SELECT COUNT(*) FROM records;", -1, &stmt, 0);
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        int count = sqlite3_column_int(stmt, 0);
        if (count == 0) {
            // Seed Records
            const char *seed_records = 
                "INSERT INTO records (artist, title, year, genre) VALUES ('Pink Floyd', 'The Dark Side of the Moon', '1973', 'Progressive Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Miles Davis', 'Kind of Blue', '1959', 'Jazz');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('The Beatles', 'Abbey Road', '1969', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Led Zeppelin', 'Led Zeppelin IV', '1971', 'Hard Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('John Coltrane', 'A Love Supreme', '1965', 'Jazz');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Fleetwood Mac', 'Rumours', '1977', 'Pop Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Nirvana', 'Nevermind', '1991', 'Grunge');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Marvin Gaye', 'What''s Going On', '1971', 'Soul');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('David Bowie', 'The Rise and Fall of Ziggy Stardust', '1972', 'Glam Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Radiohead', 'OK Computer', '1997', 'Alternative Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Pink Floyd', 'The Wall', '1979', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('The Beatles', 'Sgt. Pepper''s Lonely Hearts Club Band', '1967', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Michael Jackson', 'Thriller', '1982', 'Pop');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('AC/DC', 'Back in Black', '1980', 'Hard Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Nirvana', 'In Utero', '1993', 'Grunge');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Radiohead', 'Kid A', '2000', 'Electronic');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Miles Davis', 'Bitches Brew', '1970', 'Jazz');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('John Coltrane', 'Giant Steps', '1960', 'Jazz');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('David Bowie', 'Hunky Dory', '1971', 'Glam Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Bob Dylan', 'Highway 61 Revisited', '1965', 'Folk Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('The Clash', 'London Calling', '1979', 'Punk Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Queen', 'A Night at the Opera', '1975', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Prince', 'Purple Rain', '1984', 'Pop Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Bruce Springsteen', 'Born to Run', '1975', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('The Who', 'Who''s Next', '1971', 'Rock');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Bob Marley', 'Exodus', '1977', 'Reggae');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Marvin Gaye', 'Let''s Get It On', '1973', 'Soul');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Stevie Wonder', 'Songs in the Key of Life', '1976', 'Soul');"
                "INSERT INTO records (artist, title, year, genre) VALUES ('Black Sabbath', 'Paranoid', '1970', 'Heavy Metal');";
            sqlite3_exec(global_db, seed_records, 0, 0, 0);

            // Seed Customers
            const char *seed_customers = 
                "INSERT INTO customers (name, email) VALUES ('Alice Smith', 'alice@thin.dev');"
                "INSERT INTO customers (name, email) VALUES ('Bob Jones', 'bob@thin.dev');"
                "INSERT INTO customers (name, email) VALUES ('Charlie Brown', 'charlie@thin.dev');";
            sqlite3_exec(global_db, seed_customers, 0, 0, 0);

            // Seed Likes connections
            const char *seed_likes = 
                "INSERT INTO likes (customer_id, record_id) VALUES (1, 1);" // Alice likes Pink Floyd (Dark Side)
                "INSERT INTO likes (customer_id, record_id) VALUES (1, 2);" // Alice likes Miles Davis (Kind of Blue)
                "INSERT INTO likes (customer_id, record_id) VALUES (1, 11);" // Alice likes Pink Floyd (The Wall)
                "INSERT INTO likes (customer_id, record_id) VALUES (1, 13);" // Alice likes Michael Jackson (Thriller)
                "INSERT INTO likes (customer_id, record_id) VALUES (2, 2);" // Bob likes Miles Davis (Kind of Blue)
                "INSERT INTO likes (customer_id, record_id) VALUES (2, 3);" // Bob likes The Beatles (Abbey Road)
                "INSERT INTO likes (customer_id, record_id) VALUES (2, 14);" // Bob likes AC/DC (Back in Black)
                "INSERT INTO likes (customer_id, record_id) VALUES (2, 23);" // Bob likes Queen (A Night at the Opera)
                "INSERT INTO likes (customer_id, record_id) VALUES (3, 7);" // Charlie likes Nirvana (Nevermind)
                "INSERT INTO likes (customer_id, record_id) VALUES (3, 10);" // Charlie likes Radiohead (OK Computer)
                "INSERT INTO likes (customer_id, record_id) VALUES (3, 15);" // Charlie likes Nirvana (In Utero)
                "INSERT INTO likes (customer_id, record_id) VALUES (3, 16);"; // Charlie likes Radiohead (Kid A)
            sqlite3_exec(global_db, seed_likes, 0, 0, 0);
        }
    }
    sqlite3_finalize(stmt);
    // Note: We leave global_db OPEN for the lifetime of the service process
}

// Queries SQLite database for matching records using persistent connection
// Returns the length of the written JSON string, or -1 on error.
int query_records_sqlite(const char *raw_query, char *out_json) {
    if (!global_db) {
        init_db_schema();
        if (!global_db) {
            strcpy(out_json, "[]");
            return 2;
        }
    }

    sqlite3_stmt *res;

    // Decode percent-encoded search query
    char query[256];
    url_decode_db(query, raw_query);

    // Prepare SQL Statement with wildcards
    const char *sql = 
        "SELECT r.artist, r.title, r.year, r.genre, "
        "       COALESCE(GROUP_CONCAT(c.name, ', '), '') AS liked_by "
        "FROM records r "
        "LEFT JOIN likes l ON r.id = l.record_id "
        "LEFT JOIN customers c ON l.customer_id = c.id "
        "WHERE (? = '' OR r.artist LIKE ? OR r.title LIKE ? OR r.genre LIKE ? OR c.name LIKE ?) "
        "GROUP BY r.id;";

    int rc = sqlite3_prepare_v2(global_db, sql, -1, &res, 0);
    if (rc != SQLITE_OK) {
        strcpy(out_json, "[]");
        return 2;
    }

    // Bind parameters
    char query_wildcard[280];
    snprintf(query_wildcard, sizeof(query_wildcard), "%%%s%%", query);
    
    sqlite3_bind_text(res, 1, query, -1, SQLITE_STATIC);
    sqlite3_bind_text(res, 2, query_wildcard, -1, SQLITE_STATIC);
    sqlite3_bind_text(res, 3, query_wildcard, -1, SQLITE_STATIC);
    sqlite3_bind_text(res, 4, query_wildcard, -1, SQLITE_STATIC);
    sqlite3_bind_text(res, 5, query_wildcard, -1, SQLITE_STATIC);

    // Build JSON output
    strcpy(out_json, "[");
    int matches = 0;

    while (sqlite3_step(res) == SQLITE_ROW) {
        const char *artist = (const char *)sqlite3_column_text(res, 0);
        const char *title = (const char *)sqlite3_column_text(res, 1);
        const char *year = (const char *)sqlite3_column_text(res, 2);
        const char *genre = (const char *)sqlite3_column_text(res, 3);
        const char *liked_by = (const char *)sqlite3_column_text(res, 4);

        char record_json[512];
        snprintf(record_json, sizeof(record_json),
            "%s{\"artist\":\"%s\",\"title\":\"%s\",\"year\":\"%s\",\"genre\":\"%s\",\"liked_by\":\"%s\"}",
            matches > 0 ? "," : "",
            artist ? artist : "",
            title ? title : "",
            year ? year : "",
            genre ? genre : "",
            liked_by ? liked_by : ""
        );
        strcat(out_json, record_json);
        matches++;
    }

    strcat(out_json, "]");
    
    sqlite3_finalize(res);
    // Note: Do NOT close global_db here. Keep connection open.

    return strlen(out_json);
}

}
