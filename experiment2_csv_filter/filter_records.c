#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct {
    char artist[128];
    char title[128];
    char year[16];
    char genre[64];
} Record;

void to_lowercase(char *str) {
    for (; *str; ++str) *str = tolower((unsigned char)*str);
}

int main() {
    FILE *file = fopen("../data/records.csv", "r");
    if (!file) {
        fprintf(stderr, "Error opening records.csv from data directory\n");
        return 1;
    }

    Record records[100];
    char line[512];
    int record_count = 0;

    // Skip header line
    if (!fgets(line, sizeof(line), file)) {
        fclose(file);
        return 1;
    }

    while (fgets(line, sizeof(line), file) && record_count < 100) {
        // Strip trailing newline
        line[strcspn(line, "\r\n")] = 0;

        char *artist = strtok(line, ",");
        char *title = strtok(NULL, ",");
        char *year = strtok(NULL, ",");
        char *genre = strtok(NULL, ",");

        if (artist && title && year && genre) {
            strncpy(records[record_count].artist, artist, 128);
            strncpy(records[record_count].title, title, 128);
            strncpy(records[record_count].year, year, 16);
            strncpy(records[record_count].genre, genre, 64);
            record_count++;
        }
    }
    fclose(file);

    printf("Loaded %d records. Enter search query: ", record_count);
    fflush(stdout);

    char query[128];
    if (!fgets(query, sizeof(query), stdin)) {
        return 0;
    }
    query[strcspn(query, "\r\n")] = 0;

    char query_lower[128];
    strncpy(query_lower, query, 128);
    to_lowercase(query_lower);

    printf("\nMatching Records:\n");
    printf("--------------------------------------------------\n");

    int matches = 0;
    for (int i = 0; i < record_count; i++) {
        char temp_artist[128], temp_title[128], temp_genre[64];
        strncpy(temp_artist, records[i].artist, 128);
        strncpy(temp_title, records[i].title, 128);
        strncpy(temp_genre, records[i].genre, 64);

        to_lowercase(temp_artist);
        to_lowercase(temp_title);
        to_lowercase(temp_genre);

        if (strstr(temp_artist, query_lower) ||
            strstr(temp_title, query_lower) ||
            strstr(temp_genre, query_lower)) {
            printf("%s - \"%s\" (%s) [%s]\n", records[i].artist, records[i].title, records[i].year, records[i].genre);
            matches++;
        }
    }
    printf("--------------------------------------------------\n");
    printf("Found %d match(es).\n", matches);

    return 0;
}
