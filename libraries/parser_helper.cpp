#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>

// Disable C++ name mangling so the linker symbol matches exactly in Assembly
extern "C" {

// Helper to convert a string to lowercase in-place
void to_lowercase_c(char *str) {
    for (; *str; ++str) {
        *str = tolower((unsigned char)*str);
    }
}

// Substring case-insensitive search
// Returns 1 if query is found in text, 0 otherwise
int match_record_c(const char *text, const char *query) {
    if (!text || !query) return 0;
    if (query[0] == '\0') return 1; // Empty query matches anything

    char text_lower[256];
    char query_lower[256];

    // Safely copy and lowercase
    strncpy(text_lower, text, 255);
    text_lower[255] = '\0';
    to_lowercase_c(text_lower);

    strncpy(query_lower, query, 255);
    query_lower[255] = '\0';
    to_lowercase_c(query_lower);

    return strstr(text_lower, query_lower) ? 1 : 0;
}

// Parses a CSV line and extracts fields (Artist, Title, Year, Genre)
// Returns 1 on success, 0 on failure/incomplete line
int parse_csv_line_c(char *line, char *artist, char *title, char *year, char *genre) {
    if (!line) return 0;

    // Use strtok to split the line by comma
    char *tok_artist = strtok(line, ",");
    char *tok_title  = strtok(NULL, ",");
    char *tok_year   = strtok(NULL, ",");
    char *tok_genre  = strtok(NULL, ",");

    if (tok_artist && tok_title && tok_year && tok_genre) {
        strcpy(artist, tok_artist);
        strcpy(title, tok_title);
        strcpy(year, tok_year);
        strcpy(genre, tok_genre);
        return 1;
    }
    return 0;
}

// Computes HMAC-SHA256 of msg using key, writing output as a hex string
void hmac_sha256_hex(const char *msg, const char *key, char *out_hex) {
    unsigned char md[32];
    unsigned int md_len = 0;
    HMAC(EVP_sha256(), key, strlen(key), (const unsigned char*)msg, strlen(msg), md, &md_len);
    for (unsigned int i = 0; i < md_len; i++) {
        sprintf(out_hex + (i * 2), "%02x", md[i]);
    }
    out_hex[md_len * 2] = '\0';
}

}

#include <openssl/ssl.h>
#include <openssl/err.h>

extern "C" {

SSL_CTX *ssl_init_c() {
    SSL_library_init();
    OpenSSL_add_all_algorithms();
    SSL_load_error_strings();
    
    const SSL_METHOD *method = TLS_server_method();
    SSL_CTX *ctx = SSL_CTX_new(method);
    if (!ctx) {
        return NULL;
    }
    
    // Load cert and key
    if (SSL_CTX_use_certificate_file(ctx, "server.crt", SSL_FILETYPE_PEM) <= 0) {
        return NULL;
    }
    if (SSL_CTX_use_PrivateKey_file(ctx, "server.key", SSL_FILETYPE_PEM) <= 0) {
        return NULL;
    }
    return ctx;
}

SSL *ssl_accept_c(SSL_CTX *ctx, int client_fd) {
    SSL *ssl = SSL_new(ctx);
    if (!ssl) return NULL;
    SSL_set_fd(ssl, client_fd);
    if (SSL_accept(ssl) <= 0) {
        SSL_free(ssl);
        return NULL;
    }
    return ssl;
}

int ssl_read_c(SSL *ssl, char *buf, int num) {
    return SSL_read(ssl, buf, num);
}

int ssl_write_c(SSL *ssl, const char *buf, int num) {
    return SSL_write(ssl, buf, num);
}

void ssl_close_c(SSL *ssl) {
    if (ssl) {
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
}

void ssl_free_ctx_c(SSL_CTX *ctx) {
    if (ctx) {
        SSL_CTX_free(ctx);
    }
}

}
