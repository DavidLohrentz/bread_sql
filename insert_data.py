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
    another = input("""Would you like to enter more data?
    y) yes
    n) no\n""")

    if another.upper() == "Y":
        pick_it()
    else:
        exit(0)

def get_pid(party_name):
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()
    cursor.callproc('pid', [party_name])
    result = cursor.fetchone()
    cursor.close()
    return result[0]


def get_sid(shape_name):
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()
    cursor.callproc('sid', [shape_name])
    result = cursor.fetchone()
    cursor.close()
    return result[0]


def get_did(dough_name):
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()
    cursor.callproc('did', [dough_name])
    result = cursor.fetchone()
    cursor.close()
    return result[0]


def dough():
    which_dough = input("name of dough: \n")
    leader = int(input(f"Days of lead time for {which_dough}? \n"))
    SQL = "INSERT INTO doughs (dough_name, lead_time_days) VALUES (%s, %s)"
    data = (which_dough, leader)
    insert_data(SQL, data)

def email():
    party_name = input("what is the name of the party: ")
    pid = get_pid(party_name)
    email_type = ''
    while email_type != 'b' and email_type != 'w' and email_type != 'p':
        email_type = input("""What is the email type:
        b) business
        w) work
        p) personal\n""")
        email_type = email_type.lower()
    email = input("what is the email address: ")
    SQL = "INSERT INTO emails (party_id, email_type, email) VALUES (%s, %s, %s)"
    data = (pid, email_type, email)
    insert_data(SQL, data)

def party():
    party_name = input("what is the name of the party: ")
    party_type = ''
    while party_type != 'i' and party_type != 'o':
        party_type = input(f"Is {party_name} an individual (i) or an organization (o)? ")
    SQL = "INSERT INTO parties (party_name, party_type) VALUES (%s, %s)"
    data = (party_name, party_type)
    insert_data(SQL, data)

def ingredient():
    ingredient_name = input("What is the name of the ingredient?\n")
    is_flour = input(f"{ingredient_name} is flour: 't' = true, 'f' = false\n")
    SQL = "INSERT INTO ingredients (ingredient_name, is_flour) VALUES (%s, %s)"
    data = (ingredient_name, is_flour)
    insert_data(SQL, data)

def shape():
    shape_input = input("What is the name of the shape?\n")
    data = (shape_input, )
    SQL = "INSERT INTO shapes (shape_name) VALUES (%s);"
    insert_data(SQL, data)

def spec_ord():
    delivery = input("What is the delivery date?\n")
    cust_name = ''
    while cust_name == '':
        cust_name = input("What is the name of the customer?\n")
    cid = get_pid(cust_name)
    cust_type = ''
    while cust_type != 'i' and cust_type != 'o':
        cust_type = input("Is the customer an individual 'i' or an organization 'o'?\n")
    doe = input("What is the name of the dough?\n")
    did = get_did(doe)
    shape = input("What is the name of the shape?\n")
    sid = get_sid(shape)
    amt = int(input(f"What is the amount of {doe} shaped as {shape}\n"))
    SQL = """INSERT INTO special_orders (delivery_date, customer_id, io,
             dough_id, shape_id, amt) VALUES (%s, %s, %s, %s, %s, %s)"""
    data = (delivery, cid, cust_type, did, sid, amt)
    insert_data(SQL, data)

def pick_it():
    pick_table = input("""Insert data in which table?\n
        d) doughs
        e) emails
        i) ingredients
        p) parties
        s) shapes
        so) special orders
        \n\n""")

    if pick_table.upper() == "D":
        dough()
        another_one()

    if pick_table.upper() == "E":
        email()
        another_one()

    elif pick_table.upper() == "I":
        ingredient()
        another_one()

    elif pick_table.upper() == "P":
        party()
        another_one()

    elif pick_table.upper() == "S":
        shape()
        another_one()

    elif pick_table.upper() == "SO":
        spec_ord()
        another_one()

    else:
       pick_it()

pick_it()
