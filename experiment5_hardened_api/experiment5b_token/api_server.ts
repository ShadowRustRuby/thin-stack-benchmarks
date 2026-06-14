import * as fs from 'fs';
import { createHmac } from 'crypto';

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
            const query = url.searchParams.get('q') || '';
            
            // Calculate HMAC-SHA256 of the query
            const hmac = createHmac('sha256', 'secret');
            hmac.update(query);
            const expectedSignature = hmac.digest('hex');
            
            // Verify X-Signature header
            const signature = req.headers.get('X-Signature');
            if (signature !== expectedSignature) {
                return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                    status: 401,
                    headers: {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Connection': 'close'
                    }
                });
            }

            const queryLower = query.toLowerCase();
            const matches = records.filter(r => 
                queryLower === '' || 
                r.artist.toLowerCase().includes(queryLower) ||
                r.title.toLowerCase().includes(queryLower) ||
                r.genre.toLowerCase().includes(queryLower)
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

console.log("Secure (HMAC) TypeScript API Server running on port 8080...");
