--QLFD_SLS_AMT
SELECT
  accountnumber,
  :campaign,
  kpi_value,
  kpi_log
FROM
(
  --mailplan end calculation
  SELECT
    deb.accountnumber,
    CASE WHEN curr_cycle.kpi_val_nr >= 5
         THEN 0
         WHEN (substr(:campaign,6,2) IN ('03','06','09','12') AND deb.loa >= 3) OR deb.loa = 3
         THEN nvl(sm.prev3aws,0)
         --In all other cases take the value calculated in last campaign.
         ELSE nvl(rp.kpi_val_nr,0) END AS kpi_value, --QLFD_SLS_AMT
    CASE WHEN curr_cycle.kpi_val_nr >= 5
         THEN NULL
         WHEN (substr(:campaign,6,2) IN ('03','06','09','12') AND deb.loa >= 3) OR deb.loa = 3
         THEN 'AWS: ' || to_char(nvl(sm.prev3aws,0))
         ELSE kt.kpi_log END AS kpi_log,
    rp.kpi_val_nr,
    sm.accountnumber AS mcsr_acc,
    deb.removalreason
  FROM
  (
    SELECT/*+full(d)*/
      ltrim(d.accountnumber) AS accountnumber,
      d.loatoassign AS loa,
      d.removalreason
    FROM
      xal_live.avstructuredef asd,
      xal_live.debtable d
    WHERE asd.dataset = :dataset
      AND asd.status = 0
      AND asd.mailplan = :mailplan
      AND d.dataset = asd.dataset
      AND d.grouplevel = asd."LEVEL"
      AND d.groupcode = asd.levelcode$
  ) deb,
    xal_live.rep_prfrmnc curr_cycle,
  (
    SELECT/*+full(sls_mcsr)*/
      ltrim(accountnumber) AS accountnumber,
      SUM(awardsales) AS prev3aws
    FROM
      xal_live.sls_mcsr
    WHERE dataset = :dataset
      AND campaign BETWEEN :prevcamp2 AND :campaign
    GROUP BY
      ltrim(accountnumber)
  ) sm,
    xal_live.rep_prfrmnc rp,
    xal_live.kpi_table kt
  WHERE :mailplan IS NOT NULL
    AND curr_cycle.dataset = :dataset
    AND curr_cycle.accountnumber = deb.accountnumber
    AND curr_cycle.kpi_cd = 'CURR_CYCL_ID_NR'
    AND sm.accountnumber(+) = deb.accountnumber
    AND rp.dataset(+) = :dataset
    AND rp.accountnumber(+) = deb.accountnumber
    AND rp.kpi_cd(+) = :kpi_cd
    AND kt.dataset(+) = :dataset
    AND kt.kpi_cd(+) = :kpi_cd
    AND kt.campaign(+) = :prevcamp
    AND kt.accountnumber(+) = deb.accountnumber
)
WHERE (nvl(kpi_val_nr,-1) <> nvl(kpi_value,-1) OR --store everyone in kpi_table whose segment has changed
       mcsr_acc IS NOT NULL OR --has record in sls_mcsr
       removalreason = 0) --store everyone in staff
UNION ALL
--calculation for (re)appointments
SELECT
  ltrim(accountnumber) AS accountnumber,
  currcamp AS campaign,
  0 AS kpi_value, --QLFD_SLS_AMT
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