import psycopg2
import os

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
        phone()
    else:
        exit(0)

def phone():
    print("Let's add a phone number to the database.\n")
    party_name = input("what is the name of the party: ")
    pid = get_pid(party_name)
    phone_no = input("what is the phone number: ")
    phone_type = ''
    while phone_type != 'm' and phone_type != 'w' and phone_type != 'b' and \
            phone_type != 'f' and phone_type != 'e' and phone_type != 'h':
        phone_type = input("""What type of phone?\n
        m) mobile
        w) work
        b) business
        e) emergency
        f) fax
        h) home
        \n""")
        phone_type = phone_type.lower()
    SQL = "INSERT INTO phones (party_id, phone_type, phone_no) VALUES (%s, %s, %s)"
    data = (pid, phone_type, phone_no)
    insert_data(SQL, data)
    another_one()

phone()
