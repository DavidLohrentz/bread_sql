import psycopg2
import os

connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

cursor = connection.cursor()

def dough_insert():
    which_dough = input("name of dough to add to doughs table: ")
    leader = int(input(f"how many days of lead time for {which_dough}? "))
    try:
        SQL = "INSERT INTO doughs (dough_name, lead_time_days) VALUES (%s, %s)"
        data = (which_dough, leader)
        cursor.execute(SQL, data)
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


pick_table = input("""Insert data in which table?\n
         d) doughs
         i) ingredients
         s) shapes \n\n""")

if pick_table == "d":
    dough_insert()
elif pick_table == "i":
    print("You picked ingredients")
elif pick_table == "s":
    print("you picked shapes")
else:
    print("you suck")
