import psycopg2
import os

try:
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()

    cursor.execute('''INSERT INTO doughs (dough_name, lead_time_days)
     VALUES (%s, %s);''',
     ("foccacia", 1))
    connection.commit()
    print("Data inserted successfully into PostgreSQL")

except (Exception, psycopg2.Error) as error:
    print("Error while connecting to PostgreSQL", error)
finally:
    # closing database connection.
        if(connection):
            cursor.close()
            connection.close()
            print("PostgreSQL connection is closed")
