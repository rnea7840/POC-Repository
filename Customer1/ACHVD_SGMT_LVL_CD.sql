--ACHVD_SGMT_LVL_CD
SELECT
  ltrim(t.accountnumber) AS accountnumber,
  (SELECT MAX(rep_segment) + 1
     FROM xal_live.mrkt_sgmt_lvl
    WHERE dataset = :dataset
      AND cycle_id = t.curr_cycl_id_nr
      AND greatest(t.achvd_sls_amt,0) >= sales_threshold) AS kpi_val_nr,
  NULL AS kpi_val_txt,
  currcamp AS campaign
FROM
(
  SELECT
    kpi_accounts.*,
    (SELECT kpi_val_nr
       FROM xal_live.rep_prfrmnc
      WHERE dataset = :dataset
        AND accountnumber = ltrim(kpi_accounts.accountnumber)
        AND kpi_cd = 'CURR_CYCL_ID_NR') AS curr_cycl_id_nr,
    (SELECT kpi_val_nr
       FROM xal_live.rep_prfrmnc
      WHERE dataset = :dataset
        AND accountnumber = ltrim(kpi_accounts.accountnumber)
        AND kpi_cd = 'ACHVD_SLS_AMT') AS achvd_sls_amt
  FROM
    xal_live.kpi_accounts
  WHERE dataset = :dataset
) t