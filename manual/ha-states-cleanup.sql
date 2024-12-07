SELECT m.entity_id,
  s.metadata_id,
  s.cnt
FROM (
    SELECT COUNT(*) AS cnt,
      states.metadata_id
    FROM states
    GROUP BY states.metadata_id
    order by cnt desc
  ) s
  LEFT JOIN states_meta m ON (s.metadata_id = m.metadata_id)
WHERE entity_id LIKE "%_indicator_mode"
DELETE FROM states
WHERE metadata_id IN (
    18,
    11,
    3834,
    2841,
    881,
    2005,
    94,
    2345,
    107,
    2312,
    2485,
    2808,
    2387,
    2492,
    72,
    2001,
    2767,
    2722,
    2720,
    2721
  );
DELETE FROM states
WHERE metadata_id IN (
    SELECT metadata_id
    FROM states_meta
    WHERE entity_id LIKE "%_indicator_mode"
  )
LIMIT 1000;
-- 2024/12/03 grave cleanup

-- Select biggest sensors

SELECT COUNT(state_id) AS cnt,
  ROUND(
    SUM(LENGTH(state_attributes.shared_attrs)) / 1024 / 1024,
    1
  ) AS mbytes,
  states_meta.entity_id
FROM states
  LEFT JOIN state_attributes ON (
    states.attributes_id = state_attributes.attributes_id
  )
  LEFT JOIN states_meta ON (states.metadata_id = states_meta.metadata_id)
GROUP BY states.metadata_id
ORDER BY mbytes DESC
LIMIT 10;

SET FOREIGN_KEY_CHECKS = 0;

DELETE states 
FROM states
JOIN states_meta ON states.metadata_id = states_meta.metadata_id
WHERE states_meta.entity_id LIKE '%_power_outage_memory'
OR states_meta.entity_id LIKE '%_update_available';

DELETE FROM state_attributes
WHERE NOT EXISTS (
    SELECT 1
    FROM states sts
    WHERE sts.attributes_id = state_attributes.attributes_id
);

SET FOREIGN_KEY_CHECKS = 1;