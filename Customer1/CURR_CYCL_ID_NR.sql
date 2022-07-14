--CURR_CYCL_ID_NR
SELECT
  ltrim(accountnumber) AS accountnumber,
  CASE WHEN loatoassign BETWEEN 0 AND 2
       THEN decode(loa0_cycle - loatoassign,4,16,3,15,loa0_cycle - loatoassign)
       WHEN lastinvoice <= lastinvoice_boundary --for performance reasons, to avoid scalar query if possible
       THEN loa0_cycle
       WHEN removalreason = 0
       THEN qtr
       WHEN EXISTS (SELECT/*+index(debinvjour I_041INVACCOUNTIDX)*/ 1
                    FROM
                      xal_live.debinvjour
                    WHERE dataset = :dataset
                      AND invoiceaccount = t.accountnumber
                      AND invoicedate > t.lastinvoice_boundary
                      AND invoiceamount > 0
                      AND invoicetype = 1)
       THEN qtr
       ELSE loa0_cycle END AS kpi_val_nr, --CURR_CYCL_ID_NR
  NULL AS kpi_val_txt,
  currcamp AS campaign
FROM
(
  SELECT
    kpi_accounts.*,
    ceil(to_number(substr(currcamp,6,2)) / 3) AS qtr,
    to_number(substr(currcamp,6,2)) + 4 AS loa0_cycle,
    (SELECT trunc(sysdate) - pint + 1/86400
       FROM xal_live.sysparm
      WHERE dataset = :dataset
        AND parmcode = 'REPMR0030') AS lastinvoice_boundary
  FROM
    xal_live.kpi_accounts
  WHERE dataset = :dataset
) t