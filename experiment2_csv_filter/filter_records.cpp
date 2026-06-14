#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <algorithm>

struct Record {
    std::string artist;
    std::string title;
    std::string year;
    std::string genre;
};

std::string toLower(std::string str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    return str;
}

int main() {
    std::ifstream file("../data/records.csv");
    if (!file.is_open()) {
        std::cerr << "Error opening records.csv from data directory" << std::endl;
        return 1;
    }

    std::vector<Record> records;
    std::string line;
    
    // Skip header line
    std::getline(file, line);

    while (std::getline(file, line)) {
        std::stringstream ss(line);
        std::string artist, title, year, genre;
        
        std::getline(ss, artist, ',');
        std::getline(ss, title, ',');
        std::getline(ss, year, ',');
        std::getline(ss, genre, ',');

        records.push_back({artist, title, year, genre});
    }
    file.close();

    std::cout << "Loaded " << records.size() << " records. Enter search query: ";
    std::string query;
    if (!std::getline(std::cin, query)) return 0;
    
    std::string queryLower = toLower(query);
    std::cout << "\nMatching Records:\n";
    std::cout << "--------------------------------------------------\n";
    
    int count = 0;
    for (const auto& r : records) {
        if (toLower(r.artist).find(queryLower) != std::string::npos ||
            toLower(r.title).find(queryLower) != std::string::npos ||
            toLower(r.genre).find(queryLower) != std::string::npos) {
            std::cout << r.artist << " - \"" << r.title << "\" (" << r.year << ") [" << r.genre << "]\n";
            count++;
        }
    }
    std::cout << "--------------------------------------------------\n";
    std::cout << "Found " << count << " match(es).\n";

    return 0;
}
