import java.io.BufferedReader;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

public class FilterRecords {
    static class Record {
        String artist;
        String title;
        String year;
        String genre;

        Record(String artist, String title, String year, String genre) {
            this.artist = artist;
            this.title = title;
            this.year = year;
            this.genre = genre;
        }
    }

    public static void main(String[] args) {
        List<Record> records = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(new FileReader("../data/records.csv"))) {
            String line = br.readLine(); // Skip header
            while ((line = br.readLine()) != null) {
                String[] parts = line.split(",");
                if (parts.length >= 4) {
                    records.add(new Record(parts[0], parts[1], parts[2], parts[3]));
                }
            }
        } catch (Exception e) {
            System.err.println("Error reading records.csv: " + e.getMessage());
            System.exit(1);
        }

        System.out.print("Loaded " + records.size() + " records. Enter search query: ");
        try (Scanner scanner = new Scanner(System.in)) {
            String query = scanner.hasNextLine() ? scanner.nextLine() : "";
            String queryLower = query.toLowerCase();

            System.out.println("\nMatching Records:");
            System.out.println("--------------------------------------------------");
            int count = 0;
            for (Record r : records) {
                if (r.artist.toLowerCase().contains(queryLower) ||
                    r.title.toLowerCase().contains(queryLower) ||
                    r.genre.toLowerCase().contains(queryLower)) {
                    System.out.printf("%s - \"%s\" (%s) [%s]\n", r.artist, r.title, r.year, r.genre);
                    count++;
                }
            }
            System.out.println("--------------------------------------------------");
            System.out.println("Found " + count + " match(es).");
        }
    }
}
