CREATE OR REPLACE VIEW formula AS
SELECT bakers_percent, ingredient_name AS ingredient, 
       ROUND(get_batch_weight(:'myvar') * bakers_percent / 
       bak_per(), 0) AS overall,
       ROUND(get_batch_weight(:'myvar') * bakers_percent / 
       bak_per() * percent_of_ingredient_total /100, 0) AS sour,
       ROUND(get_batch_weight(:'myvar') * bakers_percent / bak_per() - 
       COALESCE ((get_batch_weight(:'myvar') * bakers_percent / bak_per() 
       * percent_of_ingredient_total / 100), 0), 0) AS final 
FROM dough_ingredient_list             
WHERE dough_name = :'myvar';


SELECT * FROM formula;
