*&---------------------------------------------------------------------*
*& Report ZMM_MSME_VENDOR
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
*& MODULE           : MM (Materials Management / Accounts Payable)
*& PURPOSE          : MSME Vendor Invoice Compliance Report
*& REPORT NAME      : ZMM_MSME_VENDOR
*& REQUEST NUMBER   : WSDK902276
*& TECHNICAL SPEC # : <Reference Spec Number>
*& DATE CREATED     : 03-10-2025
*& AUTHOR           : Janha, Jaishree M.S
*& REQUESTED BY     : Yogavelan.M ,Sudharsanan R G
*& BUSINESS LOGIC   :
*&   - Fetch invoices posted for MSME vendors based on selection screen inputs
*&     (Company Code, Vendor, Vendor Name, Posting Date, Fiscal Year).
*&   - Identify paid invoices and unpaid invoices using document type and
*&     clearing document logic.
*&   - Classify invoices into:
*&       • Paid within 45 days
*&       • Paid after 45 days
*&       • Outstanding invoices (<=45 days / >45 days)
*&   - Calculate counts and amounts per vendor.
*&   - Display MSME vendor details (Name, PAN) with compliance status.
*&   - Output shown in ALV Grid with totals.
*& CODING LOGIC    :
*&   1. Selection screen with Company Code, Vendor, Vendor Name, Date, Year.
*&   2. Data fetched from BKPF, BSEG, LFA1, IDS_AU_CR_DATA using INNER JOIN.
*&   3. MSME filter applied (CERT_ID = 'INSML', 'INMIC').
*&   4. Invoices split into paid/unpaid; open invoices identified.
*&   5. Days difference calculated using FM
*&      'FIMA_DAYS_AND_MONTHS_AND_YEARS'.
*&   6. Totals aggregated at vendor level (count, amount).
*&   7. ALV field catalog built, events and layout defined.
*&   8. Output displayed using REUSE_ALV_GRID_DISPLAY.
*&---------------------------------------------------------------------*
*& MODIFICATION LOG
*&---------------------------------------------------------------------*
*&                                                             Change/
*&                                                  IMS #/     Support
*& MODIFIED DATE  MODIFIED BY        REFERENCE      OSS NOTE   Request
*&----------------------------------------------------------------------
*&
*&
*&---------------------------------------------------------------------*

REPORT zmm_msme_vendor NO STANDARD PAGE HEADING.

TABLES :lfa1,bseg.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-004.
  PARAMETERS      : p_bukrs TYPE bseg-bukrs DEFAULT 'WMPL' OBLIGATORY.
  SELECT-OPTIONS  : s_lifnr FOR lfa1-lifnr,
                    s_budat FOR bseg-h_bldat.
  PARAMETERS      : p_gjahr TYPE bseg-gjahr.
SELECTION-SCREEN END OF BLOCK b1.


DATA: gt_fieldcat TYPE slis_t_fieldcat_alv,
      gs_fieldcat TYPE slis_fieldcat_alv,
      gt_event    TYPE slis_t_event,
      gs_event    TYPE slis_alv_event,
      gt_header   TYPE slis_t_listheader,
      d_layout    TYPE slis_layout_alv,
      layout      TYPE slis_layout_alv.

INCLUDE zmsme_screen_validation.
INCLUDE zmsme_declaration.

CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
  EXPORTING
   PERCENTAGE       = 10
    text = 'List being generated '.

SELECT b~bukrs, b~belnr, b~gjahr, k~lifnr,
       k~blart,k~rebzg , k~GKOAR,
       k~tsl, k~budat, k~augbl, k~augdt,
       l~name1, l~j_1ipanno
  FROM bkpf AS b
  INNER JOIN acdoca AS k ON  b~bukrs = k~rbukrs
                       AND b~belnr = k~belnr
                       AND b~gjahr = k~gjahr
  INNER JOIN lfa1 AS l ON  k~lifnr = l~lifnr
  INNER JOIN idsau_cr_data AS m ON k~lifnr = m~lifnr
  WHERE b~bukrs = @p_bukrs
    AND ( @p_gjahr IS INITIAL OR b~gjahr = @p_gjahr )
    AND l~lifnr IN @s_lifnr
    AND m~cert_id IN ('INSML','INMIC')
    AND k~blart IN ('KR','RE','KZ','ZA','AB')
    AND k~budat IN @s_budat
    AND k~koart  EQ 'K'
    AND k~rldnr EQ '0L'
   INTO TABLE @DATA(lt_result).
SORT lt_result BY lifnr.

IF lt_result IS INITIAL .
  MESSAGE 'No Data Found' TYPE 'S' DISPLAY LIKE 'E'.
ENDIF.

LOOP AT lt_result INTO DATA(wa_result).
  CASE wa_result-blart.
    WHEN 'KZ' OR 'ZA' OR 'AB'.
      APPEND wa_result TO  lt_paid_invoice.

    WHEN 'KR' OR 'RE'.
      IF wa_result-augbl EQ ''.
        APPEND wa_result TO lt_unpaid.
      ELSE.
        APPEND wa_result TO lt_unpaid_invoice.
      ENDIF.

  ENDCASE.

ENDLOOP.

LOOP AT lt_paid_invoice INTO DATA(wa_result_paid1).
  if wa_result_paid1-blart <> 'KZ'.
  READ TABLE lt_unpaid_invoice INTO DATA(lt_data_check) WITH KEY augbl = wa_result_paid1-belnr.
  IF sy-subrc = 0 .
    APPEND wa_result_paid1 TO lt_final_paid.
  ENDIF.
  ENDIF.
ENDLOOP.

LOOP AT lt_unpaid_invoice INTO DATA(wa_Residua)  .
  READ TABLE lt_paid_invoice INTO DATA(wa_data_check) WITH  KEY augbl = wa_residua-augbl.
  IF sy-subrc = 0 .
    IF wa_data_check-blart EQ 'KZ' AND wa_data_check-gkoar <> 'K'.
      IF wa_data_check-rebzg IS INITIAL.
        DELETE lt_unpaid_invoice WHERE augbl = wa_data_check-augbl AND blart EQ'KR'.
      ENDIF.
    ENDIF.
  ENDIF.

ENDLOOP.

LOOP AT lt_paid_invoice INTO DATA(wa_paid_invoice) WHERE blart eq 'KZ' AND gkoar eq 'K'.
  IF wa_paid_invoice-rebzg IS NOT INITIAL.
    READ TABLE lt_result INTO DATA(lt_unpaid_KZ) WITH key belnr = wa_paid_invoice-rebzg.
    APPEND lt_unpaid_KZ TO lt_unpaid_invoice.
  ENDIF.
ENDLOOP.


LOOP AT lt_paid_invoice INTO DATA(wa_result_paid).
  READ TABLE lt_unpaid_invoice INTO DATA(lt_data_check1) WITH KEY augbl = wa_result_paid-belnr.
  IF sy-subrc = 0 .
    APPEND wa_result_paid TO lt_final_paid.
  ENDIF.

ENDLOOP.
CLEAR: iv_temp, iv_count, wa_total.



SORT lt_unpaid_invoice BY lifnr.

CLEAR: wa_total, iv_temp, iv_count.

LOOP AT lt_unpaid_invoice INTO DATA(wa_final_paid).

  " Start of a new vendor group
  IF iv_temp IS INITIAL OR iv_temp <> wa_final_paid-lifnr.

    " Append previous vendor before starting new (but skip first iteration)
    IF iv_temp IS NOT INITIAL.
      wa_total-no_invoices = iv_count.
      APPEND wa_total TO lt_total.
      CLEAR: wa_total, iv_count.
    ENDIF.


    " Initialize new vendor
    iv_temp        = wa_final_paid-lifnr.
    wa_total-lifnr = iv_temp.
  ENDIF.

  " Accumulate totals
  iv_count       = iv_count + 1.
  wa_total-wrbtr = wa_total-wrbtr + wa_final_paid-wrbtr.

  " Calculate payment days
  DATA(lv_days) = 0.
  CALL FUNCTION 'FIMA_DAYS_AND_MONTHS_AND_YEARS'
    EXPORTING
      i_date_from = wa_final_paid-budat
      i_date_to   = wa_final_paid-augdt
    IMPORTING
      e_days      = lv_days.

  IF lv_days <= 45.
    wa_total-no_paid_within_45 = wa_total-no_paid_within_45 + 1.
    wa_total-amt_within_45     = wa_total-amt_within_45 + wa_final_paid-wrbtr.
  ELSE.
    wa_total-no_paid_after_45 = wa_total-no_paid_after_45 + 1.
    wa_total-amt_after_45     = wa_total-amt_after_45 + wa_final_paid-wrbtr.
  ENDIF.

ENDLOOP.

" Append last vendor after loop
IF iv_temp IS NOT INITIAL.
  wa_total-no_invoices = iv_count.
  APPEND wa_total TO lt_total.
ENDIF.
CLEAR: iv_temp, iv_count, wa_total.
IF lt_result IS NOT INITIAL.
  SELECT lifnr,
         bukrs,
         dmbtr,
         shkzg,
         budat,
         belnr,
         gjahr,
         blart
    FROM bsik_view
    INTO TABLE @DATA(lt_bsik)
    FOR ALL ENTRIES IN @lt_result
    WHERE lifnr = @lt_result-lifnr.

ENDIF.

"--------------------------------------------------------------
" Loop by vendor to calculate totals
"--------------------------------------------------------------
SORT lt_bsik BY lifnr.

LOOP AT lt_bsik INTO DATA(wa_bsik).

  "Skip same vendor (avoid duplicates)
  IF iv_temp = wa_bsik-lifnr.
    CONTINUE.
  ENDIF.
  iv_temp = wa_bsik-lifnr.

  "Initialize total for this vendor
  CLEAR wa_total.
  wa_total-lifnr = wa_bsik-lifnr.

  "Get all items for this vendor
  LOOP AT lt_bsik INTO DATA(wa_item) WHERE lifnr = wa_bsik-lifnr.

    "Amount based on debit/credit
    lv_amt = wa_item-dmbtr.
    IF wa_item-shkzg = 'H'.
      lv_amt = lv_amt * -1.
    ENDIF.

    "Total open amount
    wa_total-amt_open = wa_total-amt_open + lv_amt.

    "Calculate outstanding days
    CLEAR lv_days_out.
    CALL FUNCTION 'FIMA_DAYS_AND_MONTHS_AND_YEARS'
      EXPORTING
        i_date_from = wa_item-budat
        i_date_to   = sy-datum
      IMPORTING
        e_days      = lv_days_out.

    "Classify items ≤45 or >45 days
    IF lv_days_out <= 45.
      IF wa_item-blart = 'KR' OR wa_item-blart = 'RE' OR wa_item-blart = 'KZ' AND wa_item-shkzg <>'S'.
        wa_total-no_open_45  = wa_total-no_open_45 + 1.
      ENDIF.
      wa_total-amt_open_45 = wa_total-amt_open_45 + lv_amt.
    ELSE.
      IF wa_item-blart = 'KR' OR wa_item-blart = 'RE' OR wa_item-blart = 'KZ' AND wa_item-shkzg <>'S'.
        wa_total-no_open_after_45  = wa_total-no_open_after_45 + 1.
      ENDIF.
      wa_total-amt_open_after_45 = wa_total-amt_open_after_45 + lv_amt.
    ENDIF.


    IF wa_item-blart = 'KR' OR wa_item-blart = 'RE' OR wa_item-blart = 'KZ' AND wa_item-shkzg <>'S'."or wa_item-blart = 'AB'.
      wa_total-no_open = wa_total-no_open + 1.
    ENDIF.



  ENDLOOP.

  "----------------------------------------------------------
  " Merge into total internal table
  "----------------------------------------------------------
  READ TABLE lt_total INTO DATA(wa_exist) WITH KEY lifnr = wa_total-lifnr.
  IF sy-subrc = 0.
    wa_exist-no_open             = wa_exist-no_open + wa_total-no_open.
    wa_exist-amt_open            = wa_exist-amt_open + wa_total-amt_open.
    wa_exist-no_open_45          = wa_exist-no_open_45 + wa_total-no_open_45.
    wa_exist-amt_open_45         = wa_exist-amt_open_45 + wa_total-amt_open_45.
    wa_exist-no_open_after_45    = wa_exist-no_open_after_45 + wa_total-no_open_after_45.
    wa_exist-amt_open_after_45   = wa_exist-amt_open_after_45 + wa_total-amt_open_after_45.
    MODIFY lt_total FROM wa_exist INDEX sy-tabix.
  ELSE.
    APPEND wa_total TO lt_total.
  ENDIF.

  CLEAR wa_total.

ENDLOOP.

LOOP AT lt_total INTO DATA(wa_total1).
  " Check if PAN Number is initial OR Vendor Number is initial
  IF wa_total1-j_1ipanno IS INITIAL OR wa_total1-lifnr IS NOT INITIAL.

    READ TABLE lt_result INTO DATA(ls_result)
      WITH KEY lifnr = wa_total1-lifnr.

    IF sy-subrc = 0.
      wa_total1-j_1ipanno = ls_result-j_1ipanno.
      wa_total1-name      = ls_result-name1.

      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
        EXPORTING
          input  = wa_total1-lifnr
        IMPORTING
          output = wa_total1-lifnr.

      MODIFY lt_total FROM wa_total1 TRANSPORTING  j_1ipanno name lifnr
      WHERE lifnr = ls_result-lifnr.
    ENDIF.
  ENDIF.

ENDLOOP.

PERFORM display_report.
PERFORM build_events.
PERFORM build_layout.

IF lt_total IS INITIAL .
  MESSAGE 'No Data Found' TYPE 'E' DISPLAY LIKE 'S'.
ENDIF.
CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
  EXPORTING
    it_fieldcat        = gt_fieldcat
    it_events          = gt_event
    i_callback_program = sy-repid
    is_layout          = d_layout
  TABLES
    t_outtab           = lt_total
  EXCEPTIONS
    program_error      = 1
    OTHERS             = 2.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                     WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.

REFRESH lt_total[].
CLEAR gt_fieldcat.

FORM display_report.
  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'LIFNR'.
  gs_fieldcat-seltext_l = 'S.No'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NAME'.
  gs_fieldcat-seltext_l = 'Supplier Name'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'J_1IPANNO'.
  gs_fieldcat-seltext_l = 'PAN'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_INVOICES'.
  gs_fieldcat-seltext_l = 'Total Invoices Paid'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'WRBTR'.
  gs_fieldcat-seltext_l = 'Total Amount Paid'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_PAID_WITHIN_45'.
  gs_fieldcat-seltext_l = 'Paid within 45 Days - Count'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'AMT_WITHIN_45'.
  gs_fieldcat-seltext_l = 'Paid within 45 Days - Amt.'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_PAID_AFTER_45'.
  gs_fieldcat-seltext_l = 'Paid after 45 Days - Count'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'AMT_AFTER_45'.
  gs_fieldcat-seltext_l = 'Paid after 45 Days - Amt'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_OPEN'.
  gs_fieldcat-seltext_l = 'Outstanding Invoices - Count'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'AMT_OPEN'.
  gs_fieldcat-seltext_l = 'Outstanding Invoices - Amt'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_OPEN_45'.
  gs_fieldcat-seltext_l = 'Outstanding for 45days or less - Count'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'AMT_OPEN_45'.
  gs_fieldcat-seltext_l = 'Outstanding for 45days or less - Amt'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'NO_OPEN_AFTER_45'.
  gs_fieldcat-seltext_l = 'Outstanding for more than 45days - Count'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'AMT_OPEN_AFTER_45'.
  gs_fieldcat-seltext_l = 'Outstanding for more than 45days - Amt'.
  APPEND gs_fieldcat TO gt_fieldcat.

  CLEAR gs_fieldcat.
  gs_fieldcat-fieldname = 'REASON'.
  gs_fieldcat-seltext_l = 'Reason for delay'.
  APPEND gs_fieldcat TO gt_fieldcat.
ENDFORM.

FORM build_events.
  CLEAR gs_event.
  gs_event-name = 'TOP_OF_PAGE'.
  gs_event-form = 'TOP_OF_PAGE'.
  APPEND gs_event TO gt_event.
ENDFORM.
FORM build_layout .
  d_layout-colwidth_optimize = ''.
  d_layout-zebra = 'X'.
ENDFORM.

FORM top_of_page.
  DATA: ls_header TYPE slis_listheader.
  CLEAR ls_header.
  REFRESH gt_header.
  ls_header-typ  = 'H'.
  ls_header-info = 'MSME Invoice Report'.
  APPEND ls_header TO gt_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = gt_header.
ENDFORM.
