#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

// Link to our SQLite db helper functions
extern "C" {
    void init_db_schema();
    int query_records_sqlite(const char *query, char *out_json);
}

#define PORT 8080
#define BUFFER_SIZE 2048

int main() {
    // 1. Initialize SQLite schema and seed demo records/customers
    init_db_schema();

    // 2. Socket Creation
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        return 1;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // 3. Bind Socket
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        close(server_fd);
        return 1;
    }

    // 4. Listen
    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        close(server_fd);
        return 1;
    }

    printf("C++ SQLite API Server running on port %d...\n", PORT);

    // 5. Connection Loop
    while (1) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) continue;

        char request_buffer[BUFFER_SIZE] = {0};
        read(client_fd, request_buffer, BUFFER_SIZE - 1);

        // Simple HTTP Request Parser
        char *req_line = strtok(request_buffer, "\r\n");
        char query_str[128] = "";
        
        if (req_line && strncmp(req_line, "GET /api/records", 16) == 0) {
            char *q_param = strstr(req_line, "?q=");
            if (q_param) {
                q_param += 3; // Step over "?q="
                char *space = strchr(q_param, ' ');
                if (space) *space = '\0';
                strncpy(query_str, q_param, 127);
            }
        }

        // Query database directly and construct response JSON
        char json_body[16384] = {0};
        int content_length = query_records_sqlite(query_str, json_body);

        // Send HTTP Response Headers and Body
        char response_header[1024];
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
