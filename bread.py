import psycopg2
import os

try:
    connection = psycopg2.connect(user= os.environ['PGUSER'],
                                  password = os.environ['PGPASSWD'],
                                  host= os.environ['PGHOST'],
                                  port="5432",
                                  database= os.environ['PGDATABASE'])

    cursor = connection.cursor()

    create_bread_query = '''
SET timezone = 'US/Central';

-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP VIEW IF EXISTS phone_book, staff_list,
     ingredient_list, people_list, shape_list,
     ein_list, todays_orders, dough_info,
     todays_order_summary, standing_minus_holds
;

DROP FUNCTION IF EXISTS get_batch_weight,
     bak_per, formula, phone_search,
     percent_change
;

DROP TABLE IF EXISTS parties, people_st, staff_st,
     organization_st, phones, zip_codes, doughs,
     shapes, ingredients, dough_shapes,
     dough_ingredients, special_orders, ein_numbs,
     standing_orders, holds, days_of_week, mobile
;

CREATE OR REPLACE FUNCTION
       percent_change(second_value numeric,
                      first_value numeric,
                      dec_places INT DEFAULT 1)
       RETURNS numeric AS
               'SELECT ROUND(
               ((second_value - first_value) / first_value
               ) * 100, dec_places);'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE TABLE parties (
       party_id INTEGER GENERATED ALWAYS AS IDENTITY,
       party_type char(1) check (party_type in ('i', 'o')) NOT NULL,
       party_name VARCHAR(80) NOT NULL,
       PRIMARY KEY (party_id, party_type)
);

-- For "persons", a subtype of parties
CREATE TABLE people_st (
       party_id INTEGER PRIMARY KEY,
       party_type CHAR(1) default 'i' check (party_type = 'i') NOT NULL,
       first_name VARCHAR(25) NOT NULL,
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE zip_codes (
       zip CHAR(5) PRIMARY KEY,
       city VARCHAR(70) NOT NULL,
       state CHAR(2) NOT NULL
);

-- For "staff, a subtype of people
CREATE TABLE staff_st (
       party_id INTEGER PRIMARY KEY,
       party_type CHAR(1) default 'i' check (party_type = 'i') NOT NULL,
       ssn CHAR(11) NOT NULL,
       hire_date DATE NOT NULL,
       is_active BOOLEAN NOT NULL,
       street_no VARCHAR(12) NOT NULL,
       street VARCHAR(30) NOT NULL,
       zip CHAR(5) NOT NULL REFERENCES zip_codes(zip),
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type),
       FOREIGN KEY (party_id) references people_st (party_id))
;

-- For "organizations", a subtype of parties
CREATE TABLE organization_st (
       party_id INTEGER PRIMARY KEY,
       party_type CHAR(1) default 'o' check (party_type = 'o') NOT NULL,
       org_type CHAR(1) NOT NULL,
       CONSTRAINT check_org_in_list CHECK
            (org_type IN('b', 'n', 'g')),
            -- b = Business, n = Nonprofit, g = Gov't
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE ein_numbs (
       party_id INTEGER PRIMARY KEY,
       party_type CHAR(1) default 'o' check (party_type = 'o') NOT NULL,
       ein CHAR(11) UNIQUE NOT NULL,
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE phones (
       party_id INTEGER NOT NULL,
       phone_type char(1) not null default 'm' check
            (phone_type in ('w', 'h', 'f', 'b', 'm', 'e')),
            -- work, home, fax, business, mobile, emergency
       phone_no VARCHAR(25) UNIQUE NOT NULL,
       primary key (party_id, phone_type)
);

CREATE TABLE ingredients (
       ingredient_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
       ingredient_name VARCHAR(80) NOT NULL,
       manufacturer_id BIGINT NOT NULL,
       manufacturer_type char(1) check (manufacturer_type in ('i', 'o')) NOT NULL,
       is_flour BOOLEAN NOT NULL,
       FOREIGN KEY (manufacturer_id, manufacturer_type) references parties (party_id, party_type)
);

CREATE TABLE doughs (
    dough_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dough_name VARCHAR(70) UNIQUE NOT NULL,
    lead_time_days INTEGER NOT NULL
);

CREATE TABLE shapes (
    shape_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shape_name VARCHAR(70) UNIQUE NOT NULL
);

-- Doughs may be divided into multiple shapes with different weights
CREATE TABLE dough_shapes (
    dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
    shape_id INTEGER NOT NULL
             REFERENCES shapes(shape_id),
    ds_grams INTEGER NOT NULL,
    PRIMARY KEY (dough_id, shape_id)
);

CREATE TABLE dough_ingredients (
    dough_id INTEGER NOT NULL REFERENCES doughs(dough_id),
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(ingredient_id),
    bakers_percent NUMERIC (5, 2) NOT NULL,
    percent_in_sour NUMERIC NOT NULL,
    percent_in_poolish NUMERIC (5, 2)NOT NULL,
    percent_in_soaker NUMERIC NOT NULL,
    PRIMARY KEY (dough_id, ingredient_id)
);

CREATE TABLE special_orders (
       special_order_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
       delivery_date DATE NOT NULL,
       customer_id INTEGER NOT NULL,
       customer_type char(1) check (customer_type in ('i', 'o')) NOT NULL,
       dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
       shape_id INTEGER NOT NULL
             REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       order_created_at TIMESTAMPTZ DEFAULT now(),
       FOREIGN KEY (customer_id, customer_type)
               references parties (party_id, party_type)
);

CREATE TABLE days_of_week (
       dow_id SMALLINT PRIMARY KEY check (dow_id > 0 AND dow_id <= 7),
       dow_names CHAR(3) NOT NULL check (dow_names in ('Mon', 'Tue',
                 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
));

CREATE TABLE standing_orders (
       day_of_week SMALLINT check (day_of_week IN (
           1, 2, 3, 4, 5, 6, 7)) NOT NULL REFERENCES days_of_week(dow_id),
       customer_id INTEGER NOT NULL,
       customer_type char(1) check (customer_type in ('i', 'o')) NOT NULL,
       dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
       shape_id INTEGER NOT NULL
             REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       order_created_at TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, dough_id, shape_id),
       FOREIGN KEY (customer_id, customer_type)
               references parties (party_id, party_type)
);

CREATE TABLE holds (
       hold_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
       day_of_week SMALLINT check (day_of_week IN (
           1, 2, 3, 4, 5, 6, 7)) NOT NULL,
       customer_id INTEGER NOT NULL,
       dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
       shape_id INTEGER NOT NULL
             REFERENCES shapes(shape_id),
       start_date DATE NOT NULL,
       resume_date DATE,
       decrease_percent INTEGER NOT NULL check (decrease_percent <=100
                        AND decrease_percent >=0),
       FOREIGN KEY (day_of_week, customer_id, dough_id, shape_id)
               REFERENCES standing_orders (day_of_week, customer_id, dough_id, shape_id)
);

CREATE OR REPLACE VIEW ingredient_list AS
SELECT i.ingredient_id, i.ingredient_name as ingredient,
       p.party_name as manufacturer
  FROM ingredients AS i
  JOIN parties as p ON i.manufacturer_id = p.party_id
       AND i.manufacturer_type = p.party_type;

CREATE OR REPLACE VIEW phone_book AS
WITH typology (party_id, phone_type_abbr, type) AS
     (SELECT party_id, phone_type,
        CASE WHEN phone_type = 'w' THEN 'work'
             WHEN phone_type = 'h' THEN 'home'
             WHEN phone_type = 'f' THEN 'fax'
             WHEN phone_type = 'b' THEN 'business'
             WHEN phone_type = 'm' THEN 'mobile'
             WHEN phone_type = 'e' THEN 'emergency'
        END
     FROM phones),

name_join (party_id, new_name) AS
     (SELECT p.party_id,
       CASE WHEN pe.party_type = 'i' THEN pe.first_name || ' ' || p.party_name
       ELSE p.party_name
       END
     FROM parties AS p
     FULL JOIN people_st as pe on p.party_id = pe.party_id)


SELECT ph.party_id, nm.new_name AS name, p.party_type, t.type, ph.phone_no
  FROM phones AS ph
  JOIN name_join as nm on ph.party_id = nm.party_id
  JOIN typology AS t ON ph.party_id = t.party_id AND ph.phone_type = t.phone_type_abbr
  JOIN parties AS p on ph.party_id = p.party_id
  LEFT JOIN people_st AS pe ON ph.party_id = pe.party_id
 ORDER BY ph.party_id, t.type;


CREATE OR REPLACE VIEW staff_list AS
SELECT s.party_id, pe.first_name, p.party_name AS last_name,
       s.ssn, s.is_active, s.hire_date, s.street_no, s.street,
       z.city, z.state, s.zip, ph.phone_no AS mobile
FROM staff_st AS s
JOIN people_st AS pe on s.party_id = pe.party_id
JOIN parties AS p on s.party_id = p.party_id AND s.party_type = p.party_type
JOIN phone_book as ph ON s.party_id = ph.party_id
JOIN zip_codes AS z on s.zip = z.zip
WHERE ph.type = 'mobile';

CREATE OR REPLACE VIEW people_list AS
SELECT pe.party_id, pe.first_name, p.party_name AS last_name
  FROM people_st AS pe
  JOIN parties AS p ON pe.party_id = p.party_id
;

CREATE OR REPLACE VIEW shape_list AS
SELECT d.dough_name AS dough, s.shape_name AS shape,
       ds_grams AS grams FROM dough_shapes as dsw
  JOIN doughs AS d on dsw.dough_id = d.dough_id
  Join shapes as s on dsw.shape_id = s.shape_id;


CREATE OR REPLACE VIEW ein_list AS
SELECT p.party_name as name, ei.ein FROM ein_numbs AS ei
  JOIN parties AS p on ei.party_id = p.party_id
       AND ei.party_type = p.party_type;


CREATE OR REPLACE VIEW todays_orders AS
SELECT d.dough_id, p.party_name AS customer, so.delivery_date,
       d.lead_time_days AS lead_time, so.amt,
       d.dough_name, s.shape_name, dsw.ds_grams AS grams

  FROM dough_shapes AS dsw
  JOIN doughs AS d ON d.dough_id = dsw.dough_id
  JOIN shapes AS s ON s.shape_id = dsw.shape_id
  JOIN special_orders as so ON so.dough_id = dsw.dough_id
       AND s.shape_id = so.shape_id
  JOIN parties AS p on so.customer_id = p.party_id
       AND so.customer_type = p.party_type
 WHERE now()::date + d.lead_time_days = delivery_date;

CREATE OR REPLACE VIEW todays_order_summary AS
SELECT dough_id, dough_name, sum(amt * grams) AS total_grams
  FROM todays_orders
 GROUP BY dough_name, dough_id
 ORDER BY dough_id;

--same format as todays_orders but data is standing orders minus holds
CREATE OR REPLACE VIEW standing_minus_holds AS
SELECT d.dough_id, p.party_name AS customer, now()::date + d.lead_time_days AS delivery_date,
       d.lead_time_days AS lead_time, ROUND(amt::numeric *
       (1-(h.decrease_percent::numeric/100)),0) AS amt,
       d.dough_name, s.shape_name, ds.ds_grams AS grams
FROM standing_orders AS so
JOIN doughs AS d on so.dough_id = d.dough_id
LEFT JOIN holds as h ON so.dough_id = h.dough_id AND so.shape_id = h.shape_id
JOIN shapes AS s on so.shape_id = s.shape_id
JOIN days_of_week as dw on so.day_of_week = dw.dow_id
JOIN parties AS p on so.customer_id = p.party_id
     AND so.customer_type = p.party_type
JOIN dough_shapes as ds on so.dough_id = ds.dough_id
     AND s.shape_id = ds.shape_id
WHERE so.day_of_week = h.day_of_week
AND h.decrease_percent < 100
AND now()::date >= h.start_date - d.lead_time_days
AND now()::date < h.resume_date - d.lead_time_days
AND (SELECT date_part('dow', CURRENT_DATE)) + d.lead_time_days = so.day_of_week;


CREATE OR REPLACE FUNCTION
get_batch_weight(which_dough INTEGER)
RETURNS numeric AS
'SELECT (SELECT COALESCE (sum(amt * grams), 0)
   FROM todays_orders
  WHERE dough_id = which_dough) +
  (SELECT COALESCE (sum(amt * grams), 0)
     FROM standing_minus_holds
   WHERE dough_id = which_dough)
;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE VIEW dough_info AS
SELECT di.dough_id, di.bakers_percent, i.ingredient_name AS ingredient, i.is_flour,
       di.percent_in_sour, di.percent_in_poolish, di.percent_in_soaker
  FROM dough_ingredients AS di
  JOIN ingredients AS i ON di.ingredient_id = i.ingredient_id
 ORDER BY di.dough_id, i.is_flour DESC, di.bakers_percent DESC;

CREATE OR REPLACE FUNCTION bak_per(which_doe integer)
  returns numeric AS
          'SELECT sum(bakers_percent) OVER (PARTITION BY dough_id)
          FROM dough_info WHERE dough_id = which_doe;'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


--usage: SELECT "%", ingredient, overall, sour, poolish, soaker, final FROM formula(1);
CREATE OR REPLACE FUNCTION formula(my_dough_id integer)
       RETURNS TABLE (dough character varying, "%" numeric, ingredient character varying,
       overall numeric, sour numeric, poolish numeric, soaker numeric, final numeric) AS $$
       BEGIN
             RETURN QUERY
                    SELECT d.dough_name, din.bakers_percent, din.ingredient,
                    ROUND(get_batch_weight(my_dough_id) * din.bakers_percent /
                          bak_per(my_dough_id), 0),
                    ROUND(get_batch_weight(my_dough_id) * din.bakers_percent /
                          bak_per(my_dough_id) * din.percent_in_sour /100, 0),
                    ROUND(get_batch_weight(my_dough_id) * din.bakers_percent /
                          bak_per(my_dough_id) * din.percent_in_poolish /100, 1),
                    ROUND(get_batch_weight(my_dough_id) * din.bakers_percent /
                          bak_per(my_dough_id) * din.percent_in_soaker /100, 0),
                    ROUND(get_batch_weight(my_dough_id) * din.bakers_percent /
                          bak_per(my_dough_id) * (1- (din.percent_in_sour +
                          din.percent_in_poolish + din.percent_in_soaker)/100), 0)
                    FROM dough_info AS din
                    JOIN doughs AS d on din.dough_id = d.dough_id
                    WHERE din.dough_id = my_dough_id;
      END;
$$ LANGUAGE plpgsql;

       --Useage: SELECT * FROM phone_search('mad%');
CREATE OR REPLACE FUNCTION phone_search(name_snippet VARCHAR)
       RETURNS TABLE (name VARCHAR, phone_type text, phone_no VARCHAR) AS $$
       BEGIN
              RETURN QUERY
                 SELECT pb.name, pb.type, pb.phone_no
                 FROM phone_book AS pb
                 WHERE pb.name ILIKE name_snippet;
       END;
$$ LANGUAGE plpgsql;

--Insert data to test code

INSERT INTO zip_codes (zip, city, state)
VALUES (53705, 'Madison', 'WI'),
       (53703, 'Madison', 'WI'),
       (53562, 'Middleton', 'WI')
;

INSERT INTO parties (party_type, party_name)
VALUES ('i', 'mylast'),
       ('i', 'Bar'),
       ('o', 'Madison Sourdough'),
       ('o', 'Meadlowlark Organics'),
       ('o', 'Woodmans'),
       ('o', 'Willy St Coop'),
       ('o', 'King Arthur'),
       ('o', 'Redmond'),
       ('o', 'LeSaffre')
;

INSERT INTO people_st (party_id, party_type, first_name)
VALUES (1, 'i', 'myfirst'),
       (2, 'i', 'Foo')
;

            --shapes
INSERT INTO shapes (shape_name)
     VALUES ('12" Boule'),
            ('4" pan loaves'),
            ('16" pizza'),
            ('7" pita'),
            ('hard rolls')
;

            --doughs
INSERT INTO doughs (dough_name, lead_time_days)
     VALUES ('cranberry walnut', 2),
            ('pizza dough', 1),
            ('rugbrod', 2),
            ('Kamut Sourdough', 2),
            ('pita bread', 1)
;

            --ingredients
INSERT INTO ingredients (ingredient_name, manufacturer_id, manufacturer_type, is_flour)
     VALUES ('Bolted Red Fife Flour', 4, 'o', TRUE),
            ('Kamut Flour', 3, 'o', TRUE),
            ('Rye Flour', 3, 'o', TRUE),
            ('All Purpose Flour', 7, 'o', TRUE),
            ('Bread Flour', 7, 'o', TRUE),
            ('water', 1, 'i', FALSE),
            ('High Extraction Flour', 3, 'o', TRUE),
            ('Sea Salt', 8, 'o', FALSE),
            ('leaven', 1, 'i', FALSE),
            ('saf-instant yeast', '9', 'o', FALSE),
            ('dried cranberries', 6, 'o', FALSE),
            ('walnuts', 6, 'o', FALSE)
;

INSERT INTO staff_st (party_id, party_type, ssn, is_active, hire_date,
       street_no, street, zip)
VALUES (1, 'i', '123-45-6789', TRUE, '2019-10-01', '2906', 'Barlow St', 53705),
       (2, 'i', '121-21-2121', FALSE, '2017-12-30', '924', 'Williamson St', 53703)
;

INSERT INTO organization_st (party_id, party_type, org_type)
VALUES (3, 'o', 'b'),
       (4, 'o', 'n')
;

INSERT INTO ein_numbs (party_id, party_type, ein)
VALUES (3, 'o', '01-23456789'),
       (4, 'o', '11-11111111')
;

INSERT INTO phones (party_id, phone_type, phone_no)
VALUES (1, 'm', '555-1212'),
       (1, 'w', '608-555-0000'),
       (3, 'b', '608-442-8009'),
       (5, 'b', '608-555-1111'),
       (2, 'm', '608-555-2222'),
       (4, 'b', '608-555-3333'),
       (2, 'e', '608-555-1234'),
       (6, 'f', '608-000-0000')
;

            --dough_shapes
INSERT INTO dough_shapes (dough_id, shape_id, ds_grams)
     VALUES (4, 1, 1600),
            (3, 2, 1280),
            (5, 4, 105),
            (1, 1, 1600),
            (1, 5, 120),
            (2, 3, 400)
;

            --dough_ingredients
INSERT INTO dough_ingredients (dough_id, ingredient_id, bakers_percent,
            percent_in_sour, percent_in_poolish, percent_in_soaker)
     VALUES (4, 2, 40, 0, 0, 20),
            (4, 4, 30, 33, 0, 0),
            (4, 7, 30, 33, 0, 20),
            (4, 6, 80, 20, 0, 18),
            (4, 8, 1.9, 0, 0, 0),
            (1, 2, 40, 0, 0, 20),
            (1, 4, 30, 36, 0, 0),
            (1, 7, 30, 36, 0, 20),
            (1, 6, 70, 22, 0, 18),
            (1, 8, 2.0, 0, 0, 0),
            (1, 11, 25, 0, 0, 0),
            (1, 12, 25, 0, 0, 0),
            (5, 1, 50, 0, 0, 0),
            (5, 4, 50, 5.4, 0, 0),
            (5, 6, 64, 2.4, 0, 0),
            (5, 8, 1.9, 0, 0, 0),
            (2, 5, 80, 0, 25, 0),
            (2, 2, 10, 0, 0, 0),
            (2, 7, 10, 0, 0, 0),
            (2, 6, 68, 0, 20, 0),
            (2, 8, 1.9, 0, 0, 0),
            (2, 10, .05, 0, 100, 0)
;

            --special_orders
INSERT INTO special_orders (delivery_date, customer_id, customer_type, dough_id,
            shape_id, amt, order_created_at)
       VALUES
        --kamut
            ((SELECT now()::date + interval '2 days'), 1, 'i', 4, 1, 1,
            (SELECT now())),

        --pizza
            ((SELECT now()::date + interval '1 day'), 1, 'i', 2, 3, 6,
            (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), 1, 'i', 5, 4, 8,
            (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), 1, 'i', 5, 4, 4,
            (SELECT now())),

        --rugbrod
            ((SELECT now()::date + interval '2 days'), 1, 'i', 3, 2, 2,
            (SELECT now())),

        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), 1, 'i', 1, 5, 4,
            (SELECT now())),

        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), 1, 'i', 1, 1, 1,
            (SELECT now()))

;

INSERT INTO days_of_week (dow_id, dow_names)
       VALUES
            (1, 'Mon'),
            (2, 'Tue'),
            (3, 'Wed'),
            (4, 'Thu'),
            (5, 'Fri'),
            (6, 'Sat'),
            (7, 'Sun')
;

INSERT INTO standing_orders (day_of_week, customer_id, customer_type, dough_id,
            shape_id, amt, order_created_at)
       VALUES
            --kamut
            (1, 1, 'i', 4, 1, 2, (SELECT now())),
            (2, 1, 'i', 4, 1, 2, (SELECT now())),
            (3, 1, 'i', 4, 1, 1, (SELECT now())),
            (4, 1, 'i', 4, 1, 1, (SELECT now())),
            (5, 1, 'i', 4, 1, 1, (SELECT now())),
            (6, 1, 'i', 4, 1, 1, (SELECT now())),
            (7, 1, 'i', 4, 1, 2, (SELECT now()))
;

INSERT INTO holds (day_of_week, customer_id, dough_id, shape_id, start_date, resume_date, decrease_percent)
       VALUES
            (1, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),
            (2, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),
            (3, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),
            (4, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),
            (5, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),
            (6, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),
            (7, 1, 4, 1, (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50)
;
'''

    cursor.execute(create_bread_query)
    connection.commit()
    print("Tables deleted & created successfully in PostgreSQL ")

except (Exception, psycopg2.Error) as error:
    print("Error while connecting to PostgreSQL", error)
finally:
    # closing database connection.
        if(connection):
            cursor.close()
            connection.close()
            print("PostgreSQL connection is closed")
