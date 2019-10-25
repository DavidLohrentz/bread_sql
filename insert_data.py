import psycopg2
import os

def insert_data(SQL, data):
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()

    try:
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

def another_one():
    another = input("would you like to enter more data? y = yes, n = no\n")
    if another == "y":
        pick_it()
    else:
        exit(0)

def dough():
    which_dough = input("name of dough to add to doughs table: ")
    leader = int(input(f"how many days of lead time for {which_dough}? "))
    SQL = "INSERT INTO doughs (dough_name, lead_time_days) VALUES (%s, %s)"
    data = (which_dough, leader)
    insert_data(SQL, data)

def ingredient():
    ingredient_name = input("What is the name of the ingredient?\n")
    manuf_name = input("What is the party_id of the manufacturer?\n")
    manuf_type = input("Is the manufacturer an individual 'i' or organization 'o'?\n")
    is_flour = input(f"{ingredient_name} is flour: 't' = true, 'f' = false\n")
    SQL = """INSERT INTO ingredients (ingredient_name, manufacturer_id,
             manufacturer_type, is_flour) VALUES (%s, %s, %s, %s)"""
    data = (ingredient_name, manuf_name, manuf_type, is_flour)
    insert_data(SQL, data)

def shape():
    shape_input = input("What is the name of the shape?\n")
    data = (shape_input, )
    SQL = "INSERT INTO shapes (shape_name) VALUES (%s);"
    insert_data(SQL, data)

def spec_ord():
    delivery = input("What is the delivery date?\n")
    cid = input("What is the party_id of the customer?\n")
    cust_type = input("Is the customer an individual 'i' or organization 'o'?\n")
    doe = input("What is the dough_id?\n")
    sh = input("What is the shape_id?\n")
    amt = input("What is the amount?\n")
    SQL = """INSERT INTO special_orders (delivery_date, customer_id, customer_type,
             dough_id, shape_id, amt) VALUES (%s, %s, %s, %s, %s, %s)"""
    data = (delivery, cid, cust_type, doe, sh, amt)
    insert_data(SQL, data)

def pick_it():
    pick_table = input("""Insert data in which table?\n
        d) doughs
        i) ingredients
        s) shapes
        so) special orders
        \n\n""")

    if pick_table == "d":
        dough()
        another_one()

    elif pick_table == "i":
        ingredient()
        another_one()

    elif pick_table == "s":
        shape()
        another_one()

    elif pick_table == "so":
        spec_ord()
        another_one()

    else:
       pick_it()

pick_it()
