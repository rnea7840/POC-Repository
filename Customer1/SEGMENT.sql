--SEGMENT
WITH
w_deb AS
(
  SELECT/*+full(d)*/
    ltrim(d.accountnumber) AS accountnumber,
    d.loatoassign AS loa,
    d.removalreason
  FROM
    xal_live.avstructuredef asd,
    xal_live.debtable d
  WHERE :mailplan IS NOT NULL
    AND asd.dataset = :dataset
    AND asd.status = 0
    AND asd.mailplan = :mailplan
    AND d.dataset = asd.dataset
    AND d.grouplevel = asd."LEVEL"
    AND d.groupcode = asd.levelcode$
)
SELECT
  accountnumber,
  :campaign,
  kpi_value,
  kpi_log
FROM
(
  --mailplan end calculation
  SELECT
    w_deb.accountnumber,
    CASE WHEN rp.curr_cycl_id_nr >= 5
         THEN 1
         WHEN (substr(:campaign,6,2) IN ('03','06','09','12') AND w_deb.loa >= 3) OR w_deb.loa = 3
         THEN (SELECT MAX(rep_segment) + 1
                 FROM xal_live.mrkt_sgmt_lvl
                WHERE dataset = :dataset
                  AND cycle_id = nvl(rp.prv_cycl_id_nr,rp.curr_cycl_id_nr)
                  AND greatest(rp.qlfd_sls_amt,0) >= sales_threshold)
         ELSE rp.rep_segment_old END AS kpi_value, --SEGMENT (QLFD_SGMT_LVL_CD in ODS)
    CASE WHEN rp.curr_cycl_id_nr >= 5
         THEN NULL
         WHEN (substr(:campaign,6,2) IN ('03','06','09','12') AND w_deb.loa >= 3) OR w_deb.loa = 3
         THEN 'AWS: ' || to_char(nvl(rp.qlfd_sls_amt,0))
         ELSE kt.kpi_log END AS kpi_log,
    rp.rep_segment_old,
    w_deb.removalreason
  FROM
    w_deb,
  (
    SELECT
      r.accountnumber,
      MAX(CASE WHEN r.kpi_cd = 'PRV_CYCL_ID_NR' THEN r.kpi_val_nr END) AS prv_cycl_id_nr,
      MAX(CASE WHEN r.kpi_cd = 'CURR_CYCL_ID_NR' THEN r.kpi_val_nr END) AS curr_cycl_id_nr,
      MAX(CASE WHEN r.kpi_cd = 'QLFD_SLS_AMT' THEN r.kpi_val_nr END) AS qlfd_sls_amt,
      MAX(CASE WHEN r.kpi_cd = :kpi_cd THEN r.kpi_val_nr END) AS rep_segment_old
    FROM
      w_deb,
      xal_live.rep_prfrmnc r
    WHERE r.dataset = :dataset
      AND r.kpi_cd IN ('PRV_CYCL_ID_NR','CURR_CYCL_ID_NR','QLFD_SLS_AMT',:kpi_cd)
      AND w_deb.accountnumber = r.accountnumber
    GROUP BY
      r.accountnumber
  ) rp,
    xal_live.kpi_table kt
  WHERE :mailplan IS NOT NULL
    AND rp.accountnumber = w_deb.accountnumber
    AND kt.dataset(+) = :dataset
    AND kt.kpi_cd(+) = :kpi_cd
    AND kt.campaign(+) = :prevcamp
    AND kt.accountnumber(+) = w_deb.accountnumber
)
WHERE (rep_segment_old <> kpi_value OR removalreason = 0)
UNION ALL
--calculation for (re)appointments
SELECT
  ltrim(accountnumber) AS accountnumber,
  currcamp AS campaign,
  1 AS kpi_value, --SEGMENT (QLFD_SGMT_LVL_CD in ODS)
  NULL AS kpi_log
FROM
  xal_live.kpi_accounts
WHERE :mailplan IS NULL
  AND dataset = :dataset
  AND (SELECT kpi_val_nr
         FROM xal_live.rep_prfrmnc
        WHERE dataset = :dataset
          AND accountnumber = ltrim(kpi_accounts.accountnumber)
          AND kpi_cd = 'CURR_CYCL_ID_NR') >= 5 --this filter is probably unnecessary as all reapps evaluate to true