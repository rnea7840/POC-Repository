--PRV_CYCL_ID_NR
SELECT
  ltrim(accountnumber) AS accountnumber,
  CASE WHEN curr_cycl_id_nr >= 5
       THEN NULL
       WHEN (loatoassign BETWEEN 3 AND 5 AND app_camp_nr IN (1,4,7,10))
         OR (loatoassign IN (3,4) AND app_camp_nr IN (2,5,8,11))
         OR (loatoassign = 3 AND app_camp_nr IN (3,6,9,12))
       THEN app_camp_nr + 4
       WHEN curr_cycl_id_nr = 1
       THEN 4
       ELSE curr_cycl_id_nr - 1 END AS kpi_val_nr, --PRV_CYCL_ID_NR
  NULL AS kpi_val_txt,
  currcamp AS campaign
FROM
(
  SELECT
    kpi_accounts.*,
    to_number(substr(nullif(purpose,chr(2)),6,2)) AS app_camp_nr,
    (SELECT kpi_val_nr
       FROM xal_live.rep_prfrmnc
      WHERE dataset = :dataset
        AND accountnumber = ltrim(kpi_accounts.accountnumber)
        AND kpi_cd = 'CURR_CYCL_ID_NR') AS curr_cycl_id_nr
  FROM
    xal_live.kpi_accounts
  WHERE dataset = :dataset
)