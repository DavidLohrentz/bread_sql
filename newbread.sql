\c postgres

DROP DATABASE IF EXISTS bread;

CREATE DATABASE bread;

\c bread

SET timezone = 'US/Central';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE parties (
       party_id uuid default uuid_generate_v4(),
       party_type char(1) check (party_type in ('i', 'o')) NOT NULL,
       party_name VARCHAR(80) NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (party_id, party_type)
);

CREATE INDEX parties_party_name_trgm_idx ON parties 
 USING GIN (party_name gin_trgm_ops);


INSERT INTO parties (party_type, party_name)
VALUES ('i', 'Blow'),
       ('i', 'Bar'),
       ('o', 'Madison Sourdough'),
       ('o', 'Meadowlark Organics'),
       ('o', 'Woodmans'),
       ('o', 'Willy St Coop'),
       ('o', 'King Arthur'),
       ('o', 'Redmond'),
       ('o', 'LeSaffre'),
       ('o', 'Siggis'),
       ('o', 'New Glarus Brewery'),
       ('o', 'Eden'),
       ('o', 'Dept of Revenue'),
       ('o', 'Westside Farmers Market'),
       ('i', 'Latte')
;

-- For "persons", a subtype of parties
CREATE TABLE people_st (
       party_id uuid PRIMARY KEY,
       party_type CHAR(1) default 'i' check (party_type = 'i') NOT NULL,
       first_name VARCHAR(25) NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE zip_codes (
       zip CHAR(5) PRIMARY KEY,
       city VARCHAR(70) NOT NULL,
       state CHAR(2) NOT NULL
);

-- For "staff, a subtype of people
CREATE TABLE staff_st (
       party_id uuid PRIMARY KEY,
       party_type CHAR(1) default 'i' check (party_type = 'i') NOT NULL,
       ssn CHAR(11) NOT NULL,
       hire_date DATE NOT NULL,
       is_active BOOLEAN NOT NULL,
       street_no VARCHAR(12) NOT NULL,
       street VARCHAR(30) NOT NULL,
       zip CHAR(5) NOT NULL REFERENCES zip_codes(zip),
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type),
       FOREIGN KEY (party_id) references people_st (party_id),
       CONSTRAINT hire_date_after_1970 CHECK (hire_date > '1970-01-01'),
       CONSTRAINT hire_date_within_next_mon CHECK (hire_date < now()::date + interval '1 month')
);

-- For "organizations", a subtype of parties
CREATE TABLE organization_st (
       party_id uuid PRIMARY KEY,
       party_type CHAR(1) default 'o' check (party_type = 'o') NOT NULL,
       org_type CHAR(1) NOT NULL,
       CONSTRAINT check_org_in_list CHECK 
            (org_type in('b', 'c', 'n', 'g')),
            -- b = Business, c = coop, n = Nonprofit, g = Gov't
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE ein_numbs (
       party_id uuid PRIMARY KEY,
       party_type CHAR(1) default 'o' check (party_type = 'o') NOT NULL,
       ein CHAR(11) UNIQUE NOT NULL,
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE phones (
       party_id uuid,
       phone_type char(1) not null default 'm' check 
            (phone_type in ('w', 'h', 'f', 'b', 'm', 'e')),
            -- work, home, fax, business, mobile, emergency
       phone_no VARCHAR(25) UNIQUE NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       primary key (party_id, phone_type)
);

CREATE TABLE emails (
       party_id uuid NOT NULL,
       email_type char(1) not null default 'p',
            -- work, business, personal
       email VARCHAR(60) UNIQUE NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (party_id, email_type),
       CONSTRAINT email_type_from_list check 
            (email_type in ('w', 'b', 'p'))
);

CREATE TABLE ingredients (
       ingredient_id uuid PRIMARY KEY default uuid_generate_v4(),
       ingredient_name VARCHAR(80) NOT NULL,
       is_flour BOOLEAN NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ingredients_ingredient_name_trgm_idx ON ingredients 
 USING GIN (ingredient_name gin_trgm_ops);

CREATE TABLE ingredient_costs (
       ingredient_id uuid NOT NULL REFERENCES ingredients (ingredient_id),
       maker_id uuid NOT NULL, 
       mio CHAR(1) NOT NULL check (mio in ('i', 'o')),
       seller_id uuid NOT NULL, 
       sio CHAR(1) NOT NULL check (sio in ('i', 'o')),
       cost numeric(10,5) NOT NULL,
       grams numeric NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (ingredient_id, maker_id, seller_id),
       FOREIGN KEY (maker_id, mio) REFERENCES parties (party_id, party_type),
       FOREIGN KEY (seller_id, sio) REFERENCES parties (party_id, party_type)
);


CREATE TABLE cost_changes (
       ingredient_id uuid NOT NULL REFERENCES ingredients (ingredient_id),
       maker_id uuid NOT NULL, 
       mio CHAR(1) NOT NULL check (mio in ('i', 'o')),
       seller_id uuid NOT NULL, 
       sio CHAR(1) NOT NULL check (sio in ('i', 'o')),
       old_cost numeric(10,5) NOT NULL,
       new_cost numeric(10,5) NOT NULL,
       grams numeric NOT NULL,
       change_time TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (ingredient_id, maker_id, seller_id),
       FOREIGN KEY (maker_id, mio) REFERENCES parties (party_id, party_type),
       FOREIGN KEY (seller_id, sio) REFERENCES parties (party_id, party_type)
);


CREATE OR REPLACE FUNCTION record_if_cost_changed()
       RETURNS trigger AS
    $$
    BEGIN
          IF NEW.cost <> OLD.cost THEN
            INSERT INTO cost_changes (
            ingredient_id,
            maker_id,
            mio,
            seller_id,
            sio,
            old_cost,
            new_cost,
            grams,
            change_time)
        VALUES (
            OLD.ingredient_id,
            OLD.maker_id,
            OLD.mio,
            OLD.seller_id,
            OLD.sio,
            OLD.cost,
            NEW.cost,
            OLD.grams,
            now()
        );
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;


CREATE TRIGGER cost_update
       AFTER UPDATE
          on ingredient_costs
       FOR EACH ROW
       EXECUTE PROCEDURE record_if_cost_changed();


CREATE TABLE doughs (
       dough_id uuid PRIMARY KEY default uuid_generate_v4(),
       dough_name VARCHAR(70) UNIQUE NOT NULL,
       lead_time_days INTEGER NOT NULL,
       CONSTRAINT lead_time_greater_than_0 CHECK (lead_time_days >= 0),
       CONSTRAINT lead_time_less_than_8 CHECK (lead_time_days < 8)
);

CREATE INDEX doughs_dough_name_trgm_idx ON doughs 
 USING GIN (dough_name gin_trgm_ops);


CREATE TABLE shapes (
       shape_id uuid PRIMARY KEY default uuid_generate_v4(),
       shape_name VARCHAR(70) UNIQUE NOT NULL
);

-- Doughs may be divided into multiple shapes with different weights
CREATE TABLE dough_shapes (
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       ds_grams INTEGER NOT NULL,
       CONSTRAINT ds_grams_greater_than_0 CHECK (ds_grams > 0),
       CONSTRAINT ds_grams_less_than_3000 CHECK (ds_grams < 3000),
       PRIMARY KEY (dough_id, shape_id)
);

CREATE TABLE dough_ingredients (
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       bakers_percent NUMERIC (5, 2) NOT NULL,
       percent_in_sour NUMERIC NOT NULL,
       percent_in_poolish NUMERIC (5, 2) NOT NULL,
       percent_in_soaker NUMERIC NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (dough_id, ingredient_id),
       CONSTRAINT bp_positive CHECK (bakers_percent > 0),
       CONSTRAINT percent_in_sour_positive CHECK (percent_in_sour >= 0),
       CONSTRAINT percent_in_sour_max_100 CHECK (percent_in_sour <= 100),
       CONSTRAINT percent_in_poolish_positive CHECK (percent_in_poolish >= 0),
       CONSTRAINT percent_in_poolish_max_100 CHECK (percent_in_poolish <= 100),
       CONSTRAINT percent_in_soaker_positive CHECK (percent_in_soaker >= 0),
       CONSTRAINT percent_in_soaker_max_100 CHECK (percent_in_soaker <= 100)
);


CREATE TABLE dough_mods (                                                 
       mod_name VARCHAR(40) NOT NULL, 
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       bakers_percent NUMERIC (5, 2) NOT NULL,
       percent_in_sour NUMERIC NOT NULL,
       percent_in_poolish NUMERIC (5, 2)NOT NULL,
       percent_in_soaker NUMERIC NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (mod_name, dough_id, ingredient_id),
       CONSTRAINT bp_positive CHECK (bakers_percent > 0),
       CONSTRAINT percent_in_sour_positive CHECK (percent_in_sour >= 0),
       CONSTRAINT percent_in_sour_max_100 CHECK (percent_in_sour <= 100),
       CONSTRAINT percent_in_poolish_positive CHECK (percent_in_poolish >= 0),
       CONSTRAINT percent_in_poolish_max_100 CHECK (percent_in_poolish <= 100),
       CONSTRAINT percent_in_soaker_positive CHECK (percent_in_soaker >= 0),
       CONSTRAINT percent_in_soaker_max_100 CHECK (percent_in_soaker <= 100)
);

CREATE TABLE special_orders (
       delivery_date DATE NOT NULL,
       customer_id uuid NOT NULL,
       io char(1) NOT NULL,
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (delivery_date, customer_id, dough_id, shape_id, created),
       FOREIGN KEY (customer_id, io) references parties (party_id, party_type),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o')),
       CONSTRAINT delivery_date_present_or_future CHECK (delivery_date >= now()::date),
       CONSTRAINT delivery_date_in_next_6_mons CHECK (delivery_date < now()::date + interval '6 months'),
       CONSTRAINT amt_greater_than_0 CHECK (amt > 0)
);

CREATE TABLE days_of_week (
       dow_id SMALLINT PRIMARY KEY,
       dow_names CHAR(3) NOT NULL,
       CONSTRAINT dow_id_between_0_and_7 check (dow_id > 0 AND dow_id <= 7),
       CONSTRAINT dow_names_3_letter_abr check (dow_names in ('Mon', 'Tue',
                 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
));

CREATE TABLE standing_orders (
       day_of_week SMALLINT NOT NULL REFERENCES days_of_week(dow_id),
       customer_id uuid NOT NULL,
       io char(1),
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, dough_id, shape_id),
       FOREIGN KEY (customer_id, io) 
                    references parties (party_id, party_type),
       CONSTRAINT dow_in_1_thru_7 check (day_of_week IN (1, 2, 3, 4, 5, 6, 7)),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o')),
       CONSTRAINT amt_greater_than_0 CHECK (amt > 0)
);


CREATE TABLE standing_changes (
       day_of_week SMALLINT NOT NULL REFERENCES days_of_week(dow_id),
       customer_id uuid NOT NULL,
       io char(1),
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       old_amt INTEGER NOT NULL,
       new_amt INTEGER NOT NULL,
       change_time TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, dough_id, shape_id, change_time),
       FOREIGN KEY (customer_id, io) 
                    references parties (party_id, party_type),
       CONSTRAINT dow_in_1_thru_7 check (day_of_week IN (1, 2, 3, 4, 5, 6, 7)),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o'))
);

CREATE OR REPLACE FUNCTION record_if_amt_changed()
       RETURNS trigger AS
    $$
    BEGIN
          IF NEW.amt <> OLD.amt THEN
            INSERT INTO standing_changes (
            day_of_week,
            customer_id,
            io,
            dough_id,
            shape_id,
            old_amt,
            new_amt,
            change_time)
        VALUES (
            OLD.day_of_week,
            OLD.customer_id,
            OLD.io,
            OLD.dough_id,
            OLD.shape_id,
            OLD.amt,
            NEW.amt,
            now()
        );
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER amt_update
       AFTER UPDATE
          on standing_orders
       FOR EACH ROW
       EXECUTE PROCEDURE record_if_amt_changed();

CREATE TABLE holds (
       day_of_week SMALLINT NOT NULL,
       customer_id uuid NOT NULL,
       dough_id uuid NOT NULL REFERENCES doughs(dough_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       start_date DATE NOT NULL,
       resume_date DATE,
       decrease_percent INTEGER NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, dough_id, shape_id, start_date),
       FOREIGN KEY (day_of_week, customer_id, dough_id, shape_id)
               REFERENCES standing_orders (day_of_week, customer_id, dough_id, shape_id),
       CONSTRAINT dow_in_1_thru_7 check (day_of_week IN (1, 2, 3, 4, 5, 6, 7)),
       CONSTRAINT start_in_present_or_future CHECK (start_date >= now()::date),
       CONSTRAINT start_in_next_6_mons CHECK (start_date < now()::date + interval '6 months'),
       CONSTRAINT resume_in_present_or_future CHECK (resume_date >= now()::date),
       CONSTRAINT resume_in_next_6_mons CHECK (resume_date < now()::date + interval '6 months'),
       CONSTRAINT resume_after_start CHECK (resume_date > start_date),
       CONSTRAINT decrease_less_than_or_equal_100 CHECK (decrease_percent <=100),
       CONSTRAINT decrease_more_than_0 CHECK (decrease_percent >0)
);


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


CREATE OR REPLACE VIEW staff_phones AS
WITH mob_ph (
    party_id, name, party_type, type, phone_no)
AS (
    SELECT * FROM phone_book
    WHERE type = 'mobile'
)

SELECT COALESCE (ph.name, pe.first_name) AS name, 
       s.hire_date, s.is_active, COALESCE (ph.phone_no, 'none') AS mobile
FROM staff_st as s
LEFT JOIN mob_ph as ph on s.party_id = ph.party_id
JOIN people_st AS pe on s.party_id = pe.party_id;


CREATE OR REPLACE VIEW email_list AS
  WITH et (party_id, type_code, type) AS
     (SELECT party_id, email_type,  
        CASE WHEN email_type = 'w' THEN 'work'
             WHEN email_type = 'b' THEN 'business'
             WHEN email_type = 'p' THEN 'personal'
        END
     FROM emails),

name_join (party_id, new_name) AS
     (SELECT p.party_id, 
       CASE WHEN pe.party_type = 'i' THEN pe.first_name || ' ' || p.party_name
       ELSE p.party_name
       END 
     FROM parties AS p
     FULL JOIN people_st as pe on p.party_id = pe.party_id)

SELECT e.party_id, nm.new_name AS name, et.type, e.email 
  FROM emails AS e
  JOIN name_join as nm on e.party_id = nm.party_id
  JOIN et ON e.party_id = et.party_id AND e.email_type = et.type_code
  JOIN parties AS p on e.party_id = p.party_id
  LEFT JOIN people_st as pe ON e.party_id = pe.party_id;


CREATE OR REPLACE VIEW staff_list AS 
SELECT DISTINCT s.party_id, pe.first_name, p.party_name AS last_name, 
       s.ssn, s.is_active, s.hire_date, s.street_no, s.street, 
       z.city, z.state, s.zip, ph.phone_no AS mobile
FROM staff_st AS s
JOIN people_st AS pe on s.party_id = pe.party_id
JOIN parties AS p on s.party_id = p.party_id AND s.party_type = p.party_type
FULL JOIN phone_book as ph ON s.party_id = ph.party_id
JOIN zip_codes AS z on s.zip = z.zip;

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
       AND so.io = p.party_type
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
     AND so.io = p.party_type
JOIN dough_shapes as ds on so.dough_id = ds.dough_id
     AND s.shape_id = ds.shape_id
WHERE so.day_of_week = h.day_of_week
AND h.decrease_percent < 100
AND now()::date >= h.start_date - d.lead_time_days
AND now()::date < h.resume_date - d.lead_time_days
AND (SELECT date_part('dow', CURRENT_DATE)) + d.lead_time_days = so.day_of_week;


CREATE OR REPLACE FUNCTION
get_batch_weight(which_dough VARCHAR)
RETURNS numeric AS
'SELECT (SELECT COALESCE (sum(amt * grams), 0)
   FROM todays_orders
  WHERE LOWER(dough_name) LIKE LOWER(which_dough)) +
  (SELECT COALESCE (sum(amt * grams), 0)
     FROM standing_minus_holds
   WHERE LOWER(dough_name) LIKE LOWER(which_dough))
;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE VIEW dough_info AS 
SELECT di.dough_id, d.dough_name, di.bakers_percent, i.ingredient_name AS ingredient, 
       i.is_flour, di.percent_in_sour, di.percent_in_poolish, di.percent_in_soaker
  FROM dough_ingredients AS di
  JOIN ingredients AS i ON di.ingredient_id = i.ingredient_id
  JOIN doughs as d on di.dough_id = d.dough_id
 ORDER BY di.dough_id, i.is_flour DESC, di.bakers_percent DESC;


CREATE OR REPLACE VIEW standing_change_history AS
SELECT p.party_name, d.dough_name, s.shape_name, dw.dow_names,
       sc.old_amt, sc.new_amt, sc.change_time
  FROM standing_changes as sc
  JOIN parties as p on sc.customer_id = p.party_id AND sc.io = p.party_type
  JOIN doughs as d ON sc.dough_id = d.dough_id
  JOIN shapes AS s on sc.shape_id = s.shape_id
  JOIN days_of_week AS dw on sc.day_of_week = dw.dow_id;


CREATE OR REPLACE VIEW cost_change_list AS
SELECT p.party_name as maker, i.ingredient_name as item, ROUND(cc.old_cost, 2) AS old_cost, 
       ROUND(cc.new_cost, 2) AS new_cost, ROUND(cc.old_cost / grams, 5) AS old_cost_per_g, 
       ROUND(cc.new_cost / grams, 5) as new_cost_per_g, cc.grams, cc.change_time
  FROM cost_changes as cc
  JOIN ingredients as i on cc.ingredient_id = i.ingredient_id
  JOIN parties as p on cc.maker_id = p.party_id
 WHERE maker_id = p.party_id;


CREATE OR REPLACE VIEW cost_list AS
SELECT i.ingredient_id, i.ingredient_name, ROUND(ic.cost, 2) AS cost, ic.grams, 
       ROUND(ic.cost / ic.grams, 5) AS cost_per_g 
  FROM ingredient_costs AS ic
  JOIN ingredients as i on ic.ingredient_id = i.ingredient_id;


CREATE OR REPLACE VIEW total_bp AS
SELECT DISTINCT dough_name, sum(bakers_percent) OVER 
       (partition by dough_name) AS total_bp
  FROM dough_info;

CREATE OR REPLACE FUNCTION bak_per(which_doe VARCHAR)
  returns numeric AS
          'SELECT DISTINCT sum(bakers_percent) OVER (PARTITION BY dough_id)
          FROM dough_info WHERE LOWER(dough_name) LIKE LOWER(which_doe);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION pid(p_name VARCHAR)
  returns uuid AS
          'SELECT party_id FROM parties
          WHERE LOWER(party_name) LIKE LOWER(p_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION did(d_name VARCHAR)
  returns uuid AS
          'SELECT dough_id FROM doughs
          WHERE LOWER(dough_name) LIKE LOWER(d_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION iid(i_name VARCHAR)
  returns uuid AS
          'SELECT ingredient_id FROM ingredients
          WHERE LOWER(ingredient_name) LIKE LOWER(i_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION sid(s_name VARCHAR)
  returns uuid AS
          'SELECT shape_id FROM shapes
          WHERE LOWER(shape_name) LIKE LOWER(s_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


--usage: SELECT bak_per2('kam%', 'cran%');
CREATE OR REPLACE FUNCTION bak_per2(which_doe VARCHAR, mod VARCHAR)
  returns numeric AS

          'SELECT (SELECT SUM(dm.bakers_percent) 
           FROM dough_mods AS dm
           JOIN doughs AS d on dm.dough_id = d.dough_id
           WHERE LOWER(d.dough_name) LIKE LOWER(which_doe)) +
           (SELECT SUM(di.bakers_percent)
           FROM dough_ingredients AS di
           JOIN doughs as d on di.dough_id = d.dough_id
           WHERE LOWER(d.dough_name) LIKE LOWER(which_doe)
           AND di.ingredient_id NOT IN (SELECT ingredient_id 
           FROM dough_mods AS dm
           JOIN doughs AS d on dm.dough_id = d.dough_id
           WHERE LOWER(d.dough_name) LIKE LOWER(which_doe) 
           AND LOWER(mod_name) LIKE LOWER(mod)));'

LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


--usage: SELECT "%", ingredient, overall, sour, poolish, soaker, final FROM formula('kam%');
CREATE OR REPLACE FUNCTION formula(my_dough VARCHAR)
       RETURNS TABLE (dough character varying, "%" numeric, ingredient character varying,
       overall numeric, sour numeric, poolish numeric, soaker numeric, final numeric) AS $$
       BEGIN
             RETURN QUERY
                    SELECT din.dough_name, din.bakers_percent, din.ingredient,
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough), 0),
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough) * din.percent_in_sour /100, 0),
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough) * din.percent_in_poolish /100, 1),
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough) * din.percent_in_soaker /100, 0),
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough) * (1- (din.percent_in_sour + 
                          din.percent_in_poolish + din.percent_in_soaker)/100), 0)
                    FROM dough_info AS din
                    WHERE LOWER(din.dough_name) LIKE LOWER(my_dough);
      END;
$$ LANGUAGE plpgsql;

--useage: SELECT * FROM modded_formula('Kam%', 'cran%');
CREATE OR REPLACE FUNCTION modded_formula(get_dough VARCHAR, get_mod VARCHAR)
       RETURNS TABLE (dough character varying, "%" numeric, ingredient character varying,
       overall numeric, sour numeric, poolish numeric, soaker numeric, final numeric) AS $$
       BEGIN
             RETURN QUERY
            WITH dmu (
                dough_name, dough_id, ingredient_id, ingredient_name, is_flour, bakers_percent,
                percent_in_sour, percent_in_poolish, percent_in_soaker
                ) AS 
            (SELECT d.dough_name, dm.dough_id, dm.ingredient_id, i.ingredient_name, i.is_flour, dm.bakers_percent, 
            dm.percent_in_sour, dm.percent_in_poolish, dm.percent_in_soaker
FROM dough_mods as dm 
JOIN ingredients as i on dm.ingredient_id = i.ingredient_id
JOIN doughs as d on dm.dough_id = d.dough_id
     WHERE LOWER(dm.mod_name) LIKE LOWER(get_mod) AND LOWER(d.dough_name) LIKE LOWER(get_dough)
     UNION ALL
SELECT d.dough_name, di.dough_id, di.ingredient_id, i.ingredient_name, i.is_flour, di.bakers_percent, 
             di.percent_in_sour, di.percent_in_poolish, di.percent_in_soaker
FROM dough_ingredients as di 
JOIN ingredients as i on di.ingredient_id = i.ingredient_id
JOIN doughs as d on di.dough_id = d.dough_id
WHERE LOWER(d.dough_name) LIKE LOWER(get_dough)
AND di.ingredient_id NOT IN (SELECT ingredient_id FROM dough_mods)
ORDER BY is_flour DESC, bakers_percent DESC)

                    SELECT dough_name, bakers_percent, ingredient_name,
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod), 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_sour /100, 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_poolish /100, 1),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_soaker /100, 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * (1- (percent_in_sour + 
                          percent_in_poolish + percent_in_soaker)/100), 0)
                    FROM dmu
                    WHERE LOWER(dough_name) LIKE LOWER(get_dough)
                    ;
      END;
$$ LANGUAGE plpgsql;


--usage: SELECT "%", ingredient, overall, sour, poolish, soaker, final FROM formula('cran%');
CREATE OR REPLACE FUNCTION cost_form(my_dough VARCHAR)
       RETURNS TABLE (dough character varying, ingredient character varying,
       grams NUMERIC, cost numeric) AS $$
       BEGIN
             RETURN QUERY
                    SELECT din.dough_name, din.ingredient,
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough), 0),
                    ROUND(get_batch_weight(my_dough) * din.bakers_percent /
                          bak_per(my_dough), 0) * cl.cost_per_g AS item_cost
                    FROM dough_info AS din
                    JOIN cost_list as cl on din.ingredient = cl.ingredient_name
                    WHERE din.dough_name LIKE my_dough;
      END;
$$ LANGUAGE plpgsql;

-- usage: SELECT cost_per_kg('cran%');
CREATE OR REPLACE FUNCTION cost_per_kg(which_do VARCHAR)
  returns numeric AS
          'SELECT round(SUM(cost) / (SUM(grams) / 1000), 2) 
          FROM cost_form(which_do);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


       --Useage: SELECT * FROM phone_search('mad%');
CREATE OR REPLACE FUNCTION phone_search(name_snippet VARCHAR)
       RETURNS TABLE (name VARCHAR, phone_type text, phone_no VARCHAR) AS $$
       BEGIN
              RETURN QUERY
                 SELECT pb.name, pb.type, pb.phone_no
                 FROM phone_book AS pb
                 WHERE LOWER(pb.name) LIKE LOWER(name_snippet);
       END;
$$ LANGUAGE plpgsql;

--function for triggers to update any column named 'modified'
CREATE OR REPLACE FUNCTION update_modified_column() 
RETURNS TRIGGER AS $$
BEGIN
        NEW.modified = now();
            RETURN NEW; 
END;
$$ language 'plpgsql';

CREATE TRIGGER update_parties_modtime BEFORE UPDATE ON parties 
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_people_modtime BEFORE UPDATE ON people_st
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_phones_modtime BEFORE UPDATE ON phones
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_ingredients_modtime BEFORE UPDATE ON ingredients
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_ingredient_costs_modtime BEFORE UPDATE ON ingredient_costs
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_d_ingredients_modtime BEFORE UPDATE ON dough_ingredients
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_dough_mods_modtime BEFORE UPDATE ON dough_mods
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_spec_orders_modtime BEFORE UPDATE ON special_orders
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_holds_modtime BEFORE UPDATE ON holds
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_stand_orders_modtime BEFORE UPDATE ON standing_orders
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

--Insert data to test code

INSERT INTO zip_codes (zip, city, state)
VALUES (53705, 'Madison', 'WI'),
       (53703, 'Madison', 'WI'),
       (53562, 'Middleton', 'WI')
;

INSERT INTO phones (party_id, phone_type, phone_no)
VALUES (pid('Blow'), 'm', '555-1212'),
       (pid('Blow'), 'w', '608-555-0000'),
       (pid('Madison Sourdough'), 'b', '608-442-8009'),
       (pid('Woodmans'), 'b', '608-555-1111'),
       (pid('Bar'), 'm', '608-555-2222'),
       (pid('Meadowlark Organics'), 'b', '608-555-3333'),
       (pid('Bar'), 'e', '608-555-1234'),
       (pid('Willy St Coop'), 'f', '608-000-0000')
;

INSERT INTO people_st (party_id, first_name)
VALUES ((SELECT party_id FROM parties WHERE party_name = 'Blow' AND now() - modified < interval '10 sec'), 'Joe'),
       ((SELECT party_id FROM parties WHERE party_name = 'Bar' AND now() - modified < interval '10 sec'), 'Foo'),
       ((SELECT party_id FROM parties WHERE party_name = 'Latte' AND now() - modified < interval '10 sec'), 'Moka-Choka')
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
INSERT INTO ingredients (ingredient_name, is_flour)
     VALUES ('Bolted Red Fife Flour', TRUE),
            ('Kamut Flour', TRUE),
            ('Rye Flour', TRUE),
            ('All Purpose Flour', TRUE),
            ('Bread Flour', TRUE),
            ('water', FALSE),
            ('High Extraction Flour', TRUE),
            ('Sea Salt', FALSE),
            ('leaven', FALSE),
            ('saf-instant yeast', FALSE),
            ('dried cranberries', FALSE),
            ('walnuts', FALSE),
            ('Turkey Red Flour', TRUE),
            ('Filmjolk', FALSE),
            ('Barley Malt Syrup', FALSE),
            ('Sprouted Rye Berries', FALSE),
            ('Whole Flax Seeds', FALSE),
            ('Ground Flax Seeds', FALSE),
            ('Sesame Seeds', FALSE),
            ('pumpkin Seeds', FALSE)
;

            --ingredient_costs
INSERT INTO ingredient_costs (ingredient_id, maker_id, mio, seller_id, sio, cost, grams)
     VALUES 
            (iid('Bolted Red Fife Flour'), pid('Meadowlark Organics'), 'o', pid('Meadowlark Organics'), 'o', 7.00, 907),
            (iid('Kamut Flour'), pid('Madison Sourdough'), 'o', pid('Madison Sourdough'), 'o', 5.20, 907),
            (iid('Rye Flour'), pid('Madison Sourdough'), 'o', pid('Madison Sourdough'), 'o', 5.20, 907),
            (iid('All Purpose Flour'), pid('King Arthur'), 'o', pid('Woodmans'), 'o', 2.20, 907),
            (iid('Bread Flour'), pid('King Arthur'), 'o', pid('Woodmans'), 'o', 2.20, 907),
            (iid('water'), pid('Woodmans'), 'o', pid('Woodmans'), 'o', .55, 3785),
            (iid('High Extraction Flour'), pid('Madison Sourdough'), 'o', pid('Madison Sourdough'), 'o', 5.20, 907),
            (iid('Sea Salt'), pid('Redmond'), 'o', pid('Willy St Coop'), 'o', 1.25, 450),
            (iid('leaven'), pid('Blow'), 'i', pid('Blow'), 'i', .75, 300),
            (iid('saf-instant yeast'), pid('LeSaffre'), 'o', pid('Willy St Coop'), 'o', 2.50, 450),
            (iid('dried cranberries'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 7.50, 450),
            (iid('walnuts'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 7.50, 450),
            (iid('Turkey Red Flour'), pid('Meadowlark Organics'), 'o', pid('Meadowlark Organics'), 'o', 7.00, 907),
            (iid('Filmjolk'), pid('Siggis'), 'o', pid('Woodmans'), 'o', 4.00, 2000),
            (iid('Barley Malt Syrup'), pid('Eden'), 'o', pid('Willy St Coop'), 'o', 4.00, 566),
            (iid('Sprouted Rye Berries'), pid('Blow'), 'i', pid('Blow'), 'i', 1.50, 450),
            (iid('Whole Flax Seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.00, 450),
            (iid('Ground Flax Seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.00, 450),
            (iid('Sesame Seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.50, 450),
            (iid('pumpkin Seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 4.50, 450)
;


INSERT INTO staff_st (party_id, party_type, ssn, is_active, hire_date,
       street_no, street, zip)
VALUES (pid('Blow'), 'i', '123-45-6789', TRUE, '2019-10-01', '2906', 'Barlow St', 53705),
       (pid('Bar'), 'i', '121-21-2121', FALSE, '2017-12-30', '924', 'Williamson St', 53703),
       (pid('Latte'), 'i', '123-45-6666', TRUE, '2019-12-07', '2906', 'Barlow St', 53705)
;

INSERT INTO organization_st (party_id, party_type, org_type)
VALUES (pid('Madison Sourdough'), 'o', 'b'),
       (pid('Meadowlark Organics'), 'o', 'b'),
       (pid('Woodmans'), 'o', 'b'),
       (pid('Willy St Coop'), 'o', 'c'),
       (pid('King Arthur'), 'o', 'b'),
       (pid('Dept of Revenue'), 'o', 'g'),
       (pid('Westside Farmers Market'), 'o', 'n'),
       (pid('Siggis'), 'o', 'b'),
       (pid('Eden'), 'o', 'b'),
       (pid('Redmond'), 'o', 'b'),
       (pid('LeSaffre'), 'o', 'b')
;

INSERT INTO ein_numbs (party_id, party_type, ein)
VALUES (pid('Madison Sourdough'), 'o', '01-23456789'),
       (pid('Meadowlark Organics'), 'o', '11-11111111')
;

INSERT INTO emails (party_id, email_type, email)
VALUES (pid('Blow'), 'p', 'bubba@gmail.com'),
       (pid('Dept of Revenue'), 'w', 'punkinhead_sucks@traitors.com')
;


            --dough_shapes
INSERT INTO dough_shapes (dough_id, shape_id, ds_grams)
     VALUES (did('Kamut Sourdough'), sid('12" Boule'), 1600),
            (did('rugbrod'), sid('4" pan loaves'), 1280),
            (did('pita bread'), sid('7" pita'), 105),
            (did('cranberry walnut'), sid('12" Boule'), 1600),
            (did('cranberry walnut'), sid('hard rolls'), 120),
            (did('pizza dough'), sid('16" pizza'), 400)
;

            --dough_ingredients
INSERT INTO dough_ingredients (dough_id, ingredient_id, bakers_percent,
            percent_in_sour, percent_in_poolish, percent_in_soaker)
     VALUES (did('Kamut Sourdough'), iid('Kamut Flour'), 40, 0, 0, 20),
            (did('Kamut Sourdough'), iid('All Purpose Flour'), 30, 33, 0, 0),
            (did('Kamut Sourdough'), iid('High Extraction Flour'), 30, 33, 0, 20),
            (did('Kamut Sourdough'), iid('water'), 80, 20, 0, 18),
            (did('Kamut Sourdough'), iid('Sea Salt'), 1.9, 0, 0, 0),
            (did('cranberry walnut'), iid('Kamut Flour'), 40, 0, 0, 20),
            (did('cranberry walnut'), iid('All Purpose Flour'), 30, 36, 0, 0),
            (did('cranberry walnut'), iid('High Extraction Flour'), 30, 36, 0, 20),
            (did('cranberry walnut'), iid('water'), 70, 22, 0, 18),
            (did('cranberry walnut'), iid('Sea Salt'), 2.0, 0, 0, 0),
            (did('cranberry walnut'), iid('dried cranberries'), 25, 0, 0, 0),
            (did('cranberry walnut'), iid('walnuts'), 25, 0, 0, 0),
            (did('pita bread'), iid('Bolted Red Fife Flour'), 50, 0, 0, 0),
            (did('pita bread'), iid('All Purpose Flour'), 50, 5.4, 0, 0),
            (did('pita bread'), iid('water'), 64, 2.4, 0, 0),
            (did('pita bread'), iid('Sea Salt'), 1.9, 0, 0, 0),
            (did('pizza dough'), iid('Bread Flour'), 80, 0, 25, 0),
            (did('pizza dough'), iid('Kamut Flour'), 10, 0, 0, 0),
            (did('pizza dough'), iid('High Extraction Flour'), 10, 0, 0, 0),
            (did('pizza dough'), iid('water'), 68, 0, 20, 0),
            (did('pizza dough'), iid('Sea Salt'), 1.9, 0, 0, 0),
            (did('pizza dough'), iid('saf-instant yeast'), .05, 0, 100, 0)
;


--any ingredient in this table will supercede dough_ingredient values
--otherwise, all dough_ingredient values will be used
INSERT INTO dough_mods (mod_name, dough_id, ingredient_id, bakers_percent,
       percent_in_sour, percent_in_poolish, percent_in_soaker)
       VALUES ('cranberry', did('Kamut Sourdough'), iid('dried cranberries'), 20, 0, 0, 0),
              ('cranberry', did('Kamut Sourdough'), iid('water'), 75, 20, 0, 18),
              ('cranberry', did('Kamut Sourdough'), iid('Sea Salt'), 2.0, 0, 0, 0)
;

            --special_orders
INSERT INTO special_orders (delivery_date, customer_id, io, dough_id,
            shape_id, amt, modified)
       VALUES 
        --kamut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', did('Kamut Sourdough'), 
                sid('12" Boule'), 1, (SELECT now())),

        --pizza
            ((SELECT now()::date + interval '1 day'), pid('Blow'), 'i', did('pizza dough'), 
                sid('16" pizza'), 6, (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), pid('Blow'), 'i', did('pita bread'), 
                sid('7" pita'), 8, (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), pid('Bar'), 'i', did('pita bread'), 
                sid('7" pita'), 4, (SELECT now())),
        
        --rugbrod
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', did('rugbrod'), 
                sid('4" pan loaves'), 2, (SELECT now())),

        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', did('cranberry walnut'), 
                sid('hard rolls'), 4, (SELECT now())),

        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', did('cranberry walnut'), 
                sid('12" Boule'), 1, (SELECT now()))
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

INSERT INTO standing_orders (day_of_week, customer_id, io, dough_id,
            shape_id, amt, modified)
       VALUES 
            --kamut
            (1, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 2, (SELECT now())),
            (2, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 2, (SELECT now())),
            (3, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 1, (SELECT now())),
            (4, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 1, (SELECT now())),
            (5, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 1, (SELECT now())),
            (6, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 1, (SELECT now())),
            (7, pid('Blow'), 'i', did('Kamut Sourdough'), sid('12" Boule'), 4, (SELECT now()))
;

INSERT INTO holds (day_of_week, customer_id, dough_id, shape_id, start_date, resume_date, decrease_percent)
       VALUES
            (1, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),
        
            (2, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),

            (3, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),

            (4, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),
        
            (5, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),

            (6, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 100),

            (7, pid('Blow'), did('Kamut Sourdough'), sid('12" Boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50)
;

UPDATE standing_orders 
   SET amt = 2
 WhERE day_of_week = 7 AND customer_id = pid('Blow')
   AND dough_id = did('Kamut Sourdough');


UPDATE parties
SET party_name = 'Dept of Shenanigans'
WHERE party_name Like 'Dept%';

UPDATE ingredient_costs
   SET cost = 5.00
 WHERE ingredient_id = iid('Kamut Flour')
