import csv

def main():
    try:
        records = []
        with open('../data/records.csv', mode='r', encoding='utf-8') as f:
            reader = csv.reader(f)
            # Skip header
            next(reader)
            for row in reader:
                if len(row) >= 4:
                    records.append({
                        'artist': row[0],
                        'title': row[1],
                        'year': row[2],
                        'genre': row[3]
                    })

        query = input(f"Loaded {len(records)} records. Enter search query: ")
        query_lower = query.lower()
        
        print("\nMatching Records:")
        print("--------------------------------------------------")
        
        count = 0
        for r in records:
            if (query_lower in r['artist'].lower() or 
                query_lower in r['title'].lower() or 
                query_lower in r['genre'].lower()):
                print(f"{r['artist']} - \"{r['title']}\" ({r['year']}) [{r['genre']}]")
                count += 1
                
        print("--------------------------------------------------")
        print(f"Found {count} match(es).")

    except Exception as e:
        print("Error:", e)

if __name__ == '__main__':
    main()
