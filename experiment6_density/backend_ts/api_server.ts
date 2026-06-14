import * as fs from 'fs';

interface Record {
    artist: string;
    title: string;
    year: string;
    genre: string;
}

// Load CSV
const csvData = fs.readFileSync('../../data/records.csv', 'utf-8');
const lines = csvData.split(/\r?\n/).filter(line => line.trim().length > 0);
// Skip header
const records: Record[] = [];
for (let i = 1; i < lines.length; i++) {
    const parts = lines[i].split(',');
    if (parts.length >= 4) {
        records.push({
            artist: parts[0],
            title: parts[1],
            year: parts[2],
            genre: parts[3]
        });
    }
}

Bun.serve({
    port: 8080,
    fetch(req) {
        const url = new URL(req.url);
        if (url.pathname === '/api/records') {
            const query = url.searchParams.get('q')?.toLowerCase() || '';
            const matches = records.filter(r => 
                query === '' || 
                r.artist.toLowerCase().includes(query) ||
                r.title.toLowerCase().includes(query) ||
                r.genre.toLowerCase().includes(query)
            );
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

console.log("TypeScript API Server running on port 8080...");
