#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

// Link to our shared parser library functions
extern "C" {
    int match_record_c(const char *text, const char *query);
    int parse_csv_line_c(char *line, char *artist, char *title, char *year, char *genre);
}

#define PORT 8080
#define BUFFER_SIZE 2048

typedef struct {
    char artist[128];
    char title[128];
    char year[16];
    char genre[64];
} Record;

int load_records(Record *records) {
    FILE *file = fopen("../../data/records.csv", "r");
    if (!file) {
        return 0;
    }

    char line[512];
    int count = 0;
    
    // Skip header
    if (!fgets(line, sizeof(line), file)) {
        fclose(file);
        return 0;
    }

    while (fgets(line, sizeof(line), file) && count < 100) {
        // Strip trailing newlines
        line[strcspn(line, "\r\n")] = 0;

        char artist[128], title[128], year[16], genre[64];
        if (parse_csv_line_c(line, artist, title, year, genre)) {
            strcpy(records[count].artist, artist);
            strcpy(records[count].title, title);
            strcpy(records[count].year, year);
            strcpy(records[count].genre, genre);
            count++;
        }
    }
    fclose(file);
    return count;
}

int main() {
    Record records[100];
    int record_count = load_records(records);
    if (record_count == 0) {
        fprintf(stderr, "Error: Failed to load records from CSV database\n");
        return 1;
    }

    // 1. Socket Creation
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        return 1;
    }

    // Set socket options to reuse port (prevents port lockouts on restart)
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // 2. Bind Socket
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        close(server_fd);
        return 1;
    }

    // 3. Listen
    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        close(server_fd);
        return 1;
    }

    printf("Secure API Server running on port %d...\n", PORT);

    // 4. Connection Loop
    while (1) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) continue;

        char request_buffer[BUFFER_SIZE] = {0};
        read(client_fd, request_buffer, BUFFER_SIZE - 1);

        // Security check: Verify X-API-Key: secure123 is present in the request headers
        if (!strstr(request_buffer, "X-API-Key: secure123")) {
            const char *unauth_header = 
                "HTTP/1.1 401 Unauthorized\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "Connection: close\r\n"
                "Content-Length: 24\r\n\r\n";
            const char *unauth_body = "{\"error\":\"Unauthorized\"}";
            write(client_fd, unauth_header, strlen(unauth_header));
            write(client_fd, unauth_body, strlen(unauth_body));
            close(client_fd);
            continue;
        }

        // Simple HTTP Request Parser
        // Extract query parameter from URL (e.g. GET /api/records?q=Jazz HTTP/1.1)
        char *req_line = strtok(request_buffer, "\r\n");
        char query_str[128] = "";
        
        if (req_line && strncmp(req_line, "GET /api/records", 16) == 0) {
            char *q_param = strstr(req_line, "?q=");
            if (q_param) {
                q_param += 3; // Step over "?q="
                char *space = strchr(q_param, ' ');
                if (space) *space = '\0'; // Null-terminate at end of path
                strncpy(query_str, q_param, 127);
            }
        }

        // Build Response Body (JSON Array)
        char json_body[4096] = "[";
        int matches = 0;

        for (int i = 0; i < record_count; i++) {
            // Check if record matches query
            if (query_str[0] == '\0' || 
                match_record_c(records[i].artist, query_str) ||
                match_record_c(records[i].title, query_str) ||
                match_record_c(records[i].genre, query_str)) {
                
                char item[256];
                snprintf(item, sizeof(item), 
                    "%s{\"artist\":\"%s\",\"title\":\"%s\",\"year\":\"%s\",\"genre\":\"%s\"}",
                    matches > 0 ? "," : "",
                    records[i].artist, records[i].title, records[i].year, records[i].genre
                );
                strcat(json_body, item);
                matches++;
            }
        }
        strcat(json_body, "]");

        // Send HTTP Response Headers and Body
        char response_header[1024];
        int content_length = strlen(json_body);
        
        snprintf(response_header, sizeof(response_header),
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Content-Length: %d\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Connection: close\r\n\r\n",
            content_length
        );

        write(client_fd, response_header, strlen(response_header));
        write(client_fd, json_body, content_length);

        close(client_fd);
    }

    close(server_fd);
    return 0;
}
