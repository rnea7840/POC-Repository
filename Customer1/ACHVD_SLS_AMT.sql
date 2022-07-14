--ACHVD_SLS_AMT
SELECT
  ltrim(d.accountnumber) AS accountnumber,
  nvl((SELECT
         SUM(awardsales)
       FROM
         xal_live.sls_mcsr
       WHERE dataset = :dataset
         AND campaign BETWEEN d.mcsr_startcamp AND d.lastcampend
         AND accountnumber = d.accountnumber),0)
    + nvl((SELECT
             SUM(awardsales)
           FROM
             xal_live.debinvjour
           WHERE dataset = :dataset
             AND purpose = d.currcamp
             AND invoiceaccount = d.accountnumber),0) AS kpi_val_nr,
  NULL AS kpi_val_txt,
  currcamp AS campaign
FROM
(
  SELECT
    kpi_accounts.*,
    CASE WHEN loatoassign = 0
         THEN NULL
         WHEN loatoassign = 1
         THEN lastcampend
         WHEN loatoassign = 2
         THEN (SELECT xal_live.prevcamp(:dataset,lastcampend) FROM dual)
         WHEN (SELECT kpi_val_nr
                 FROM xal_live.rep_prfrmnc
                WHERE dataset = :dataset
                  AND accountnumber = ltrim(kpi_accounts.accountnumber)
                  AND kpi_cd = 'CURR_CYCL_ID_NR') >= 5
         THEN NULL
         WHEN substr(lastcampend,6,2) IN ('01','04','07','10')
         THEN lastcampend
         WHEN substr(lastcampend,6,2) IN ('02','05','08','11')
         THEN (SELECT xal_live.prevcamp(:dataset,lastcampend) FROM dual) END AS mcsr_startcamp
  FROM
    xal_live.kpi_accounts
  WHERE dataset = :dataset
) d