import os
from sqlalchemy import text, inspect
from database import mysql_engine as engine
from models import Base

def fix_schema():
    """
    Compares the SQLAlchemy models with the actual database schema
    and adds any missing columns.
    """
    print("\n" + "="*60)
    print("FIXING DATABASE SCHEMA")
    print("="*60 + "\n")
    
    inspector = inspect(engine)
    
    with engine.connect() as conn:
        # Iterate through all models defined in Base
        for table_name, table in Base.metadata.tables.items():
            print(f"Checking table: {table_name}")
            
            # Get existing columns in the database
            try:
                existing_columns = [col['name'] for col in inspector.get_columns(table_name)]
            except Exception as e:
                print(f"  ⚠️ Table {table_name} does not exist yet. Skipping.")
                continue
                
            # Compare with model columns
            for column in table.columns:
                if column.name not in existing_columns:
                    print(f"  [+] Adding missing column: {column.name}")
                    
                    # Determine SQL type
                    col_type = str(column.type).upper()
                    if "VARCHAR" in col_type:
                        col_def = f"{col_type}"
                    elif "INTEGER" in col_type:
                        col_def = "INT"
                    elif "FLOAT" in col_type:
                        col_def = "FLOAT"
                    elif "TEXT" in col_type:
                        col_def = "TEXT"
                    elif "TIMESTAMP" in col_type:
                        # Handle DEFAULT CURRENT_TIMESTAMP for created_at/timestamp
                        default = ""
                        if column.server_default is not None:
                            default = " DEFAULT CURRENT_TIMESTAMP"
                        col_def = f"TIMESTAMP{default}"
                    else:
                        col_def = col_type
                        
                    nullable = " NOT NULL" if not column.nullable else ""
                    
                    try:
                        alter_query = f"ALTER TABLE {table_name} ADD COLUMN {column.name} {col_def}{nullable}"
                        conn.execute(text(alter_query))
                        conn.commit()
                        print(f"  ✅ Successfully added {column.name} to {table_name}")
                    except Exception as e:
                        print(f"  ❌ Error adding {column.name}: {e}")
                else:
                    # print(f"  - Column {column.name} exists.")
                    pass
    
    print("\n" + "="*60)
    print("SCHEMA FIX COMPLETE")
    print("="*60 + "\n")

if __name__ == "__main__":
    fix_schema()
