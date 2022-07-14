--FT_SGMT_LVL_CD
--mailplan end calculation
SELECT
  accountnumber,
  :campaign AS campaign,
  kpi_value,
  NULL AS kpi_log
FROM
(
  SELECT
    t.accountnumber,
    CASE WHEN t.curr_cycle >= 5 --still NEWREP
         THEN NULL
         WHEN t.prev_cycle >= 5 AND t.curr_cycle < 5 --reps changing right now from NEWREP to some other segment then by definition it's a first time achievement
         THEN t.rep_segment
         WHEN substr(:campaign,6,2) IN ('03','06','09','12') --for reps in regular cycles set first time achievement only at quarter end (if applicable)
          AND NOT EXISTS (SELECT 1
                            FROM xal_live.kpi_table
                           WHERE dataset = :dataset
                             AND accountnumber = t.accountnumber
                             AND kpi_cd = :rep_segment_kpi_cd
                             AND campaign < :campaign
                             AND kpi_value >= t.rep_segment
                             AND campaign >= '2021-03' --new segmentation model intro campaign
                             AND campaign >= t.reappcamp)
         THEN t.rep_segment
         WHEN substr(:campaign,6,2) IN ('03','06','09','12') --if current segment calculated at quarter end had been achieved/surpassed before
         THEN NULL
         ELSE t.ft_sgmt_lvl_cd END AS kpi_value, --otherwise do not change first time achievement value
    t.ft_sgmt_lvl_cd AS ft_sgmt_lvl_cd_current
  FROM
  (
    SELECT
      ltrim(d.accountnumber) AS accountnumber,
      d.reappcamp,
      currcycle.kpi_val_nr AS curr_cycle,
      prevcycle.kpi_val_nr AS prev_cycle,
      ft_achieve.kpi_val_nr AS ft_sgmt_lvl_cd,
      CASE WHEN currcycle.kpi_val_nr < 5
           THEN (SELECT kpi_val_nr
                   FROM xal_live.rep_prfrmnc
                  WHERE dataset = :dataset
                    AND accountnumber = ltrim(d.accountnumber)
                    AND kpi_cd = :rep_segment_kpi_cd) END AS rep_segment
    FROM
      xal_live.avstructuredef asd,
      xal_live.debtable d,
      xal_live.rep_prfrmnc currcycle,
      xal_live.rep_prfrmnc prevcycle,
      xal_live.rep_prfrmnc ft_achieve --first time achieved rep segment
    WHERE asd.dataset = :dataset
      AND asd.status = 0
      AND asd.mailplan = :mailplan
      AND d.dataset = asd.dataset
      AND d.grouplevel = asd."LEVEL"
      AND d.groupcode = asd.levelcode$
      AND currcycle.dataset = d.dataset
      AND currcycle.accountnumber = ltrim(d.accountnumber)
      AND currcycle.kpi_cd = 'CURR_CYCL_ID_NR'
      AND prevcycle.dataset = d.dataset
      AND prevcycle.accountnumber = ltrim(d.accountnumber)
      AND prevcycle.kpi_cd = 'PRV_CYCL_ID_NR'
      AND ft_achieve.dataset(+) = d.dataset
      AND ft_achieve.accountnumber(+) = ltrim(d.accountnumber)
      AND ft_achieve.kpi_cd(+) = :kpi_cd
  ) t
)
WHERE :mailplan IS NOT NULL
  AND decode(ft_sgmt_lvl_cd_current,kpi_value,0,1) = 1
UNION ALL
--recalculation for reappointments or manual segment updates during campaign
SELECT
  accountnumber,
  currcamp AS campaign,
  kpi_value,
  NULL AS kpi_log
FROM
(
  SELECT
    t.accountnumber,
    CASE WHEN curr_cycle >= 5 --still NEWREP
         THEN NULL
         WHEN NOT EXISTS (SELECT 1
                            FROM xal_live.kpi_table
                           WHERE dataset = :dataset
                             AND accountnumber = t.accountnumber
                             AND kpi_cd = :rep_segment_kpi_cd
                             AND campaign < t.lastcampend
                             AND kpi_value >= t.rep_segment
                             AND campaign >= '2021-03' --new segmentation model intro campaign
                             AND campaign >= t.reappcamp)
         THEN t.rep_segment
         ELSE t.ft_sgmt_lvl_cd_current END AS kpi_value, --otherwise do not change first time achievement value
    t.currcamp,
    t.ft_sgmt_lvl_cd_current
  FROM
  (
    SELECT
      base.*,
      CASE WHEN curr_cycle >= 5
           THEN (SELECT kpi_val_nr
                   FROM xal_live.rep_prfrmnc
                  WHERE dataset = :dataset
                    AND accountnumber = base.accountnumber
                    AND kpi_cd = :rep_segment_kpi_cd) END AS rep_segment,
      CASE WHEN curr_cycle >= 5
           THEN (SELECT kpi_val_nr
                   FROM xal_live.rep_prfrmnc
                  WHERE dataset = :dataset
                    AND accountnumber = base.accountnumber
                    AND kpi_cd = :kpi_cd) END AS ft_sgmt_lvl_cd_current
    FROM
    (
      SELECT
        ltrim(accountnumber) AS accountnumber,
        lastcampend,
        currcamp,
        reappcamp,
        (SELECT kpi_val_nr
           FROM xal_live.rep_prfrmnc
          WHERE dataset = :dataset
            AND accountnumber = ltrim(kpi_accounts.accountnumber)
            AND kpi_cd = 'CURR_CYCL_ID_NR') AS curr_cycle
      FROM
        xal_live.kpi_accounts
      WHERE dataset = :dataset
    ) base
  ) t
)
WHERE :mailplan IS NULL
  AND decode(ft_sgmt_lvl_cd_current,kpi_value,0,1) = 1