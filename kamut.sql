       --update bkrs_percent_sum view for this formula
CREATE OR REPLACE VIEW bkrs_percent_sum AS 
SELECT sum(bakers_percent) / 100
  FROM dough_ingredients
 WHERE dough_id = 4;


CREATE OR REPLACE VIEW kamut_quant AS 
SELECT so.amt, d.dough_name, s.shape_name, dsw.dough_shape_grams AS grams
  FROM dough_shape_weights AS dsw
       JOIN doughs AS d
       ON d.dough_id = dsw.dough_id

       JOIN shapes AS s
       ON s.shape_id = dsw.shape_id

       JOIN special_orders as so
       ON so.dough_id = dsw.dough_id
 WHERE d.dough_name = 'Kamut Sourdough';

SELECT * FROM kamut_quant;


--query the bakers %, ingredient and grams for each item in this formula
CREATE OR REPLACE VIEW formula AS 
SELECT di.bakers_percent AS "bakers %", i.ingredient_name as ingredient,
 ROUND ((di.bakers_percent / 100) * 
       (SELECT amt FROM kamut_quant)  
       * dsw.dough_shape_grams / (SELECT * FROM bkrs_percent_sum))
    AS grams
  FROM doughs AS d
       INNER JOIN dough_ingredients AS di 
       ON di.dough_id = d.dough_id

       INNER JOIN dough_shape_weights AS dsw 
       ON dsw.dough_id = d.dough_id

       INNER JOIN ingredients AS i 
       ON i.ingredient_id = di.ingredient_id
 WHERE d.dough_id = 4
 ORDER BY i.is_flour DESC, di.bakers_percent DESC;


SELECT * FROM formula;


SELECT p.preferment, i.ingredient_name AS ingredient, 
 ROUND (percent_of_ingredient_total * 
       (SELECT grams FROM formula AS f WHERE f.ingredient = i.ingredient_name) 
       / 100) AS grams 
  FROM dough_preferments AS dp

       INNER JOIN ingredients AS i 
       ON dp.ingredient_id = i.ingredient_id

       INNER JOIN preferments AS p 
       ON dp.preferment_id = p.preferment_id;

--SELECT * FROM ferment;

--instructions
SELECT instructions
  FROM dough_instructions AS di
 WHERE dough_id = 4;
