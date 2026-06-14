FROM oven/bun:alpine

WORKDIR /app/experiment7_sql/backend_ts
COPY api_server.ts ./

# Create data directory
RUN mkdir -p /app/data

EXPOSE 8080
CMD ["bun", "run", "api_server.ts"]
