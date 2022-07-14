--NEW_SGMT_LVL_DT
SELECT
  ltrim(accountnumber) AS accountnumber,
  NULL AS kpi_val_nr,
  to_char((SELECT enddate + 1
             FROM xal_live.purpose_con
            WHERE dataset = :dataset
              AND campnumber$ = CASE WHEN loatoassign IN (0,1)
                                     THEN cdw_interface.pkg_as_spec_util.get_next_camp(:dataset,currcamp,2 - loatoassign)
                                     WHEN loatoassign = 2
                                     THEN currcamp
                                     WHEN (SELECT kpi_val_nr
                                             FROM xal_live.rep_prfrmnc
                                            WHERE dataset = :dataset
                                              AND accountnumber = ltrim(kpi_accounts.accountnumber)
                                              AND kpi_cd = 'CURR_CYCL_ID_NR') >= 5
                                     THEN cdw_interface.pkg_as_spec_util.get_next_camp(:dataset,currcamp,2)
                                     WHEN substr(currcamp,6,2) IN ('01','04','07','10')
                                     THEN cdw_interface.pkg_as_spec_util.get_next_camp(:dataset,currcamp,2)
                                     WHEN substr(currcamp,6,2) IN ('02','05','08','11')
                                     THEN cdw_interface.pkg_as_spec_util.get_next_camp(:dataset,currcamp,1)
                                     ELSE currcamp END),'YYYYMMDD') AS kpi_val_txt, --NEW_SGMT_LVL_DT
  currcamp AS campaign
FROM
  xal_live.kpi_accounts
WHERE dataset = :dataset