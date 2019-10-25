import psycopg2
import os

which_dough = input("name of dough to add to doughs table: ")
leader = int(input(f"how many days of lead time for {which_dough}? "))
try:
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()

    cursor.execute('''INSERT INTO doughs (dough_name, lead_time_days)
     VALUES (%s, %s);''',
     (which_dough, leader))
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
