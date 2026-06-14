interface Record {
    artist: string;
    title: string;
    year: string;
    genre: string;
}

// Elements
const globalSearch = document.getElementById('globalSearch') as HTMLInputElement;

// 1. Client elements
const clientList = document.getElementById('clientList') as HTMLDivElement;
const clientLatency = document.getElementById('clientLatency') as HTMLSpanElement;
const clientHeapVal = document.getElementById('clientHeapVal') as HTMLDivElement;

// 2. Assembly elements
const asmList = document.getElementById('asmList') as HTMLDivElement;
const asmLatency = document.getElementById('asmLatency') as HTMLSpanElement;

// 3. C++ elements
const cppList = document.getElementById('cppList') as HTMLDivElement;
const cppLatency = document.getElementById('cppLatency') as HTMLSpanElement;

// 4. TypeScript elements
const tsList = document.getElementById('tsList') as HTMLDivElement;
const tsLatency = document.getElementById('tsLatency') as HTMLSpanElement;

// 5. Rust elements
const rustList = document.getElementById('rustList') as HTMLDivElement;
const rustLatency = document.getElementById('rustLatency') as HTMLSpanElement;

let cachedRecords: Record[] = [];

// Dynamic Client Memory Heap Tracker
function updateClientMemory() {
    const perf = performance as any;
    if (perf.memory) {
        // Chromium supports performance.memory
        const heapBytes = perf.memory.usedJSHeapSize;
        const heapMb = heapBytes / (1024 * 1024);
        clientHeapVal.textContent = `${heapMb.toFixed(2)} MB`;
    } else {
        // Fallback: estimate serialized size of records cache
        const serializedSize = JSON.stringify(cachedRecords).length * 2; // ~2 bytes per character in JS String
        const estMb = serializedSize / (1024 * 1024);
        clientHeapVal.textContent = estMb > 0.01 ? `${estMb.toFixed(3)} MB` : `< 0.01 MB`;
    }
}

// Initialize baseline data
async function initialize() {
    try {
        const start = performance.now();
        // Fetch baseline records from Assembly API (Port 8081)
        const response = await fetch('http://localhost:8081/api/records');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        cachedRecords = await response.json();
        const elapsed = performance.now() - start;

        // Render initially
        renderList(cachedRecords, clientList);
        renderList(cachedRecords, asmList);
        renderList(cachedRecords, cppList);
        renderList(cachedRecords, tsList);
        renderList(cachedRecords, rustList);

        const loadedText = `Loaded: ${elapsed.toFixed(1)} ms`;
        clientLatency.textContent = loadedText;
        asmLatency.textContent = loadedText;
        cppLatency.textContent = loadedText;
        tsLatency.textContent = loadedText;
        rustLatency.textContent = loadedText;

        updateClientMemory();
    } catch (error) {
        console.error('Failed to initialize comparison:', error);
        const errorHtml = `<div style="text-align: center; color: #EF4444; padding: 1rem;">Failed to connect to backend ports. Make sure they are running.</div>`;
        clientList.innerHTML = errorHtml;
        asmList.innerHTML = errorHtml;
        cppList.innerHTML = errorHtml;
        tsList.innerHTML = errorHtml;
        rustList.innerHTML = errorHtml;
    }
}

// Perform client-side local memory filtering
function filterClientSide(query: string) {
    const start = performance.now();
    const normalizedQuery = query.toLowerCase().trim();
    
    const filtered = cachedRecords.filter(r => 
        r.title.toLowerCase().includes(normalizedQuery) ||
        r.artist.toLowerCase().includes(normalizedQuery) ||
        r.genre.toLowerCase().includes(normalizedQuery) ||
        r.year.toLowerCase().includes(normalizedQuery)
    );

    renderList(filtered, clientList);
    const duration = performance.now() - start;
    clientLatency.textContent = `Query: ${duration.toFixed(2)} ms`;
    
    updateClientMemory();
}

// Fetch from backend API at specific port
async function fetchFromPort(query: string, port: number, targetList: HTMLDivElement, targetLatencyBadge: HTMLSpanElement, label: string) {
    const start = performance.now();
    const cleanQuery = query.trim();
    
    try {
        const response = await fetch(`http://localhost:${port}/api/records?q=${encodeURIComponent(cleanQuery)}`);
        const duration = performance.now() - start;

        if (response.status === 503) {
            targetLatencyBadge.textContent = `Rate Limited (503)`;
            targetList.innerHTML = `
                <div style="text-align: center; color: #EF4444; padding: 0.75rem; border: 1px dashed rgba(239, 68, 68, 0.4); border-radius: 8px; background: rgba(239, 68, 68, 0.05); font-size: 0.85rem;">
                    <strong>503 Rate Limited</strong><br>
                    <span>NGINX/Gateway limit breached</span>
                </div>`;
            return;
        }

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const records: Record[] = await response.json();
        renderList(records, targetList);
        targetLatencyBadge.textContent = `${duration.toFixed(1)} ms`;
    } catch (error: any) {
        console.error(`Fetch to port ${port} failed:`, error);
        targetList.innerHTML = `<div style="text-align: center; color: #EF4444; font-size: 0.85rem; padding: 0.5rem;">Connection error</div>`;
        targetLatencyBadge.textContent = `Error`;
    }
}

// Common renderer
function renderList(records: Record[], targetElement: HTMLDivElement) {
    if (records.length === 0) {
        targetElement.innerHTML = `<div style="text-align: center; color: #9CA3AF; padding: 1rem; font-size: 0.9rem;">No records.</div>`;
        return;
    }

    targetElement.innerHTML = records.map(r => `
        <div class="record-card">
            <div class="record-title">${escapeHtml(r.title)}</div>
            <div class="record-artist">${escapeHtml(r.artist)}</div>
            <div class="record-meta">
                <span class="badge">${escapeHtml(r.genre)}</span>
                <span class="badge" style="background: rgba(6, 182, 212, 0.1); color: #06B6D4;">${escapeHtml(r.year)}</span>
            </div>
        </div>
    `).join('');
}

function escapeHtml(str: string): string {
    return str
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

// Bind live global search event
globalSearch.addEventListener('input', (e) => {
    const val = (e.target as HTMLInputElement).value;
    
    // Execute all queries in parallel
    filterClientSide(val);
    fetchFromPort(val, 8081, asmList, asmLatency, 'Assembly');
    fetchFromPort(val, 8082, cppList, cppLatency, 'C++');
    fetchFromPort(val, 8083, tsList, tsLatency, 'TypeScript');
    fetchFromPort(val, 8084, rustList, rustLatency, 'Rust');
});

// Load on start
window.addEventListener('DOMContentLoaded', () => {
    initialize();
});
