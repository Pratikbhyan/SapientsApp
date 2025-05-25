import csv
import os
import sys

def process_transcription(csv_path, content_id):
    """Process the transcription CSV and return a list of SQL INSERT statements."""
    sql_statements = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        for row in reader:
            if len(row) >= 3:  # Ensure we have all required columns
                start, end, text = row[0], row[1], row[2]
                # Skip any empty rows or invalid data
                if not start or not end or not text:
                    continue
                # Clean and escape the text for SQL
                text = text.replace("'", "''").strip()
                sql = f"""INSERT INTO transcriptions (content_id, text, start_time, end_time) 
                       VALUES ('{content_id}', '{text}', {start}, {end});"""
                sql_statements.append(sql)
    return sql_statements

def main():
    if len(sys.argv) != 2:
        print("Usage: python process_transcription.py <content_id>")
        sys.exit(1)
        
    content_id = sys.argv[1]
    csv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'transcription_unsettling.csv')
    
    if not os.path.exists(csv_path):
        print(f"Error: File not found: {csv_path}")
        sys.exit(1)
    
    try:
        statements = process_transcription(csv_path, content_id)
        print("BEGIN;")
        for sql in statements:
            print(sql)
        print("COMMIT;")
    except Exception as e:
        print(f"Error processing file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
