SET timezone = 'US/Central';

-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP VIEW IF EXISTS phone_book, staff_list,
     ingredient_list, people_list, shape_list,
     bp, ein_list, todays_orders, dough_ingredient_list,
     dough_ingredient_list1, preferment_tab
;

DROP FUNCTION IF EXISTS get_orders, get_batch_weight,
     bak_per, formula, phone_search, formula1
;

DROP TABLE IF EXISTS parties, people_st, staff_st, 
     organization_st, phones, zip_codes, doughs,
     shapes, ingredients, dough_shape_weights,
     dough_ingredients, preferments, dough_preferments,
     special_orders, emp_id_numbs
;

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

CREATE TABLE preferments (
       preferment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
       preferment VARCHAR(50) UNIQUE NOT NULL
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

CREATE TABLE emp_id_numbs (
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

CREATE TABLE dough_preferments (
       dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
       preferment_id INTEGER NOT NULL
                  REFERENCES preferments(preferment_id),
       ingredient_id INTEGER NOT NULL
                  REFERENCES ingredients(ingredient_id),
       percent_of_ingredient_total NUMERIC,
       PRIMARY KEY (dough_id, preferment_id, ingredient_id)
);

CREATE TABLE shapes (
    shape_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shape_name VARCHAR(70) UNIQUE NOT NULL
);

-- Doughs may be divided into multiple shapes with different weights
CREATE TABLE dough_shape_weights (
    dough_id INTEGER NOT NULL
             REFERENCES doughs(dough_id),
    shape_id INTEGER NOT NULL
             REFERENCES shapes(shape_id),
    dough_shape_grams INTEGER NOT NULL,
    PRIMARY KEY (dough_id, shape_id)
);

CREATE TABLE dough_ingredients (
    dough_id INTEGER NOT NULL REFERENCES doughs(dough_id),
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(ingredient_id),
    bakers_percent NUMERIC (4, 1) NOT NULL,
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

CREATE OR REPLACE VIEW preferment_tab AS
select dp.dough_id, dp.preferment_id, dp.ingredient_id, 
       CASE when dp.preferment_id = 1 THEN dp.percent_of_ingredient_total
            ELSE null
       END AS sour,
       CASE when dp.preferment_id = 2 THEN dp.percent_of_ingredient_total
            ELSE null
       END AS poolish,
       CASE when dp.preferment_id = 3 THEN dp.percent_of_ingredient_total
            ELSE null
       END AS soaker
  FROM dough_preferments AS dp;

CREATE OR REPLACE VIEW shape_list AS 
SELECT d.dough_name AS dough, s.shape_name AS shape, 
       dough_shape_grams AS grams FROM dough_shape_weights as dsw
  JOIN doughs AS d on dsw.dough_id = d.dough_id
  Join shapes as s on dsw.shape_id = s.shape_id;

CREATE OR REPLACE VIEW bp AS 
SELECT di.dough_id, di.bakers_percent, d.dough_name, i.ingredient_name  
  FROM dough_ingredients AS di
  JOIN doughs AS d on di.dough_id = d.dough_id
  JOIN ingredients AS i ON di.ingredient_id = i.ingredient_id;

CREATE OR REPLACE VIEW ein_list AS 
SELECT p.party_name as name, ei.ein FROM emp_id_numbs AS ei 
  JOIN parties AS p on ei.party_id = p.party_id 
       AND ei.party_type = p.party_type;

CREATE OR REPLACE VIEW todays_orders AS 
SELECT d.dough_id, so.delivery_date, d.lead_time_days AS lead_time, so.amt, 
       d.dough_name, s.shape_name, dsw.dough_shape_grams AS grams
    
  FROM dough_shape_weights AS dsw 
  JOIN doughs AS d ON d.dough_id = dsw.dough_id
  JOIN shapes AS s ON s.shape_id = dsw.shape_id
  JOIN special_orders as so ON so.dough_id = dsw.dough_id
 WHERE now()::date + d.lead_time_days = delivery_date;

CREATE OR REPLACE FUNCTION
get_orders(which_dough INTEGER)
RETURNS BIGINT AS
'SELECT sum(amt)
   FROM todays_orders
  WHERE dough_id = which_dough
;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE FUNCTION
get_batch_weight(which_dough INTEGER)
RETURNS BIGINT AS
'SELECT sum(amt * grams)
   FROM todays_orders
  WHERE dough_id = which_dough
;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE VIEW dough_ingredient_list AS 
SELECT d.dough_id, di.bakers_percent, d.dough_name, 
       i.ingredient_name, i.is_flour, pr.preferment, 
       dp.percent_of_ingredient_total 
  FROM dough_ingredients as di
  JOIN ingredients AS i
       ON di.ingredient_id = i.ingredient_id
  LEFT JOIN dough_preferments as dp
       ON di.dough_id = dp.dough_id AND i.ingredient_id = dp.ingredient_id
  FULL JOIN preferments AS pr ON dp.preferment_id = pr.preferment_id
  JOIN doughs AS d on di.dough_id = d.dough_id
 ORDER BY d.dough_id
;

CREATE OR REPLACE FUNCTION bak_per()
RETURNS numeric AS
     'SELECT sum(bakers_percent) OVER (PARTITION BY dough_id)
       FROM dough_ingredient_list;'
LANGUAGE SQL
;

CREATE OR REPLACE FUNCTION formula(my_dough_id integer) 
       RETURNS TABLE (dough character varying, bakers_percent numeric, ingredient character varying, 
       overall numeric, sour numeric, final numeric) AS $$
       BEGIN
             RETURN QUERY
                 SELECT d.dough_name, dil.bakers_percent, dil.ingredient_name, 
                 ROUND(get_batch_weight(my_dough_id) * dil.bakers_percent / 
                 bak_per(), 0),
                 ROUND(get_batch_weight(my_dough_id) * dil.bakers_percent / 
                 bak_per() * dil.percent_of_ingredient_total /100, 0),
                 ROUND(get_batch_weight(my_dough_id) * dil.bakers_percent / bak_per() - 
                 COALESCE ((get_batch_weight(my_dough_id) * dil.bakers_percent / bak_per() 
                 * dil.percent_of_ingredient_total / 100), 0), 0) 
                 FROM dough_ingredient_list AS dil
                 JOIN doughs AS d on dil.dough_id = d.dough_id
                 WHERE dil.dough_id = my_dough_id;
       END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION phone_search(name_snippet character varying)
       RETURNS TABLE (who character varying, phone_no text, phone_type character varying) AS $$
       BEGIN
              RETURN QUERY
                 SELECT pb.name, pb.type, pb.phone_no
                 FROM phone_book AS pb
                 WHERE pb.name ILIKE '%name_snippet%';
       END;
$$ LANGUAGE plpgsql;

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

            --preferments
INSERT INTO preferments (preferment)
     VALUES ('sour'),
            ('poolish'),
            ('soaker')
;

            --shapes
INSERT INTO shapes (shape_name)
     VALUES ('12" Boule'),
            ('4" pan loaves'),
            ('16" pizza'),
            ('7" pita')
;

            --doughs
INSERT INTO doughs (dough_name, lead_time_days)
     VALUES ('cranberry walnut Sourdough', 2),
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
            ('saf-instant yeast', '9', 'o', FALSE)
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

INSERT INTO emp_id_numbs (party_id, party_type, ein)
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

            --dough_shape_weights
INSERT INTO dough_shape_weights (dough_id, shape_id, dough_shape_grams)
     VALUES (4, 1, 1600),
            (3, 2, 1280),
            (5, 4, 105),
            (2, 3, 400)
;

            --dough_ingredients
INSERT INTO dough_ingredients (dough_id, ingredient_id, bakers_percent)
     VALUES (4, 2, 40),
            (4, 4, 30),
            (4, 7, 30),
            (4, 6, 80),
            (4, 8, 1.9),
            (5, 1, 50),
            (5, 4, 50),
            (5, 6, 60),
            (5, 8, 1.9),
            (2, 5, 80),
            (2, 2, 10),
            (2, 7, 10),
            (2, 6, 68),
            (2, 10, .05)
;
            
            --dough_preferments
INSERT INTO dough_preferments (dough_id, preferment_id, ingredient_id,
            percent_of_ingredient_total)
     VALUES (4, 1, 4, 33 ),
            (4, 1, 7, 33 ),
            (4, 1, 6, 20 ),
            (4, 3, 2, 20),
            (4, 3, 7, 20),
            (4, 3, 6, 18),
            (5, 1, 4, 6 ),
            (5, 1, 6, 2.9 ),
            (2, 2, 5, 25),
            (2, 2, 6, 20),
            (2, 2, 10, 100)
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
            (SELECT now()))
;

