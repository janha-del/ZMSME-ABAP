*&---------------------------------------------------------------------*
*& Include          ZMSME_SCREEN_VALIDATION
*&---------------------------------------------------------------------*

AT SELECTION-SCREEN.


  SELECT COUNT(*) FROM t001 WHERE bukrs = @p_bukrs INTO @DATA(lv_cnt).
  IF lv_cnt = 0.
    MESSAGE e001(00) WITH text-000.
    set CURSOR FIELD p_bukrs.
  ENDIF.


  IF s_lifnr[] IS NOT INITIAL.
    SELECT COUNT(*) FROM lfa1
      WHERE lifnr IN @s_lifnr
      INTO @lv_cnt.
    IF lv_cnt = 0.
      MESSAGE e001(00) WITH text-001.
      set CURSOR FIELD s_lifnr.
    ENDIF.
  ENDIF.


  IF p_gjahr IS NOT INITIAL.
    IF p_gjahr < '1900' OR p_gjahr > '9999'.
      MESSAGE e001(00) WITH text-002.
      set CURSOR FIELD p_gjahr .
    ENDIF.
  ENDIF.
