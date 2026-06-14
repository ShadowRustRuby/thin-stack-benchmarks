FROM oven/bun:alpine

WORKDIR /app/experiment6_density/backend_ts
COPY api_server.ts ./

# Copy records.csv to matching relative path (../../data/records.csv)
COPY records.csv /app/data/records.csv

EXPOSE 8080
CMD ["bun", "run", "api_server.ts"]
