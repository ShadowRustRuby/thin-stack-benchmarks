import * as fs from 'fs';
import * as readline from 'readline';

interface Record {
  artist: string;
  title: string;
  year: string;
  genre: string;
}

async function main() {
  try {
    const content = fs.readFileSync('../data/records.csv', 'utf-8');
    const lines = content.split('\n').filter(line => line.trim() !== '');
    
    // Remove header
    lines.shift();

    const records: Record[] = lines.map(line => {
      const [artist, title, year, genre] = line.split(',');
      return { artist, title, year, genre };
    });

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(`Loaded ${records.length} records. Enter search query: `, (query) => {
      const queryLower = query.toLowerCase();
      console.log("\nMatching Records:");
      console.log("--------------------------------------------------");
      
      let count = 0;
      for (const r of records) {
        if (
          r.artist.toLowerCase().includes(queryLower) ||
          r.title.toLowerCase().includes(queryLower) ||
          r.genre.toLowerCase().includes(queryLower)
        ) {
          console.log(`${r.artist} - "${r.title}" (${r.year}) [${r.genre}]`);
          count++;
        }
      }
      console.log("--------------------------------------------------");
      console.log(`Found ${count} match(es).`);
      rl.close();
    });

  } catch (err) {
    console.error('Error:', err);
  }
}

main();
