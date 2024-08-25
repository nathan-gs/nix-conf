SELECT
 m.entity_id, s.metadata_id, s.cnt
FROM
(SELECT
  COUNT(*) AS cnt,
  states.metadata_id 
FROM states
GROUP BY states.metadata_id
order by cnt desc) s
LEFT JOIN states_meta m ON (s.metadata_id = m.metadata_id)
WHERE entity_id LIKE "%_indicator_mode"


DELETE FROM states WHERE metadata_id IN (18, 11, 3834, 2841, 881, 2005, 94, 2345, 107, 2312, 2485, 2808, 2387, 2492, 72, 2001, 2767, 2722, 2720, 2721);

DELETE FROM states WHERE metadata_id IN (SELECT metadata_id FROM states_meta WHERE entity_id LIKE "%_indicator_mode") LIMIT 1000;