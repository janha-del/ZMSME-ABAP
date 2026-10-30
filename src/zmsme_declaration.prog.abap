
*&---------------------------------------------------------------------*
*& Include          ZMSME_DECLARATION
*&---------------------------------------------------------------------*


TYPES: BEGIN OF ty_result,
         bukrs     TYPE bukrs,
         belnr     TYPE belnr_d,
         gjahr     TYPE gjahr,
         lifnr     TYPE lifnr,
         blart     TYPE blart,
         rebzg     TYPE rebzg,
         GKOAR     TYPE GKOAR,
         wrbtr     TYPE wrbtr,
         budat     TYPE budat,
         augbl     TYPE belnr_d,
         augdt     TYPE budat,
         name1     TYPE lfa1-name1,
         j_1ipanno TYPE lfa1-j_1ipanno,
       END OF ty_result,

       BEGIN OF ty_result_1,
         lifnr       TYPE lifnr,
         no_invoices TYPE i,
         wrbtr       TYPE wrbtr,
       END OF ty_result_1,
       BEGIN OF ty_total,
         lifnr             TYPE lifnr,
         name              TYPE name1,
         j_1ipanno         TYPE j_1ipanno,
         no_invoices       TYPE i,
         wrbtr             TYPE wrbtr,
         "Paid split
         no_paid_within_45 TYPE i,
         amt_within_45     TYPE wrbtr,
         no_paid_after_45  TYPE i,
         amt_after_45      TYPE wrbtr,
         "Unpaid (open) overall
         no_open           TYPE i,
         amt_open          TYPE wrbtr,
         "Unpaid (open) split
         no_open_45        TYPE i,
         amt_open_45       TYPE wrbtr,
         no_open_after_45  TYPE i,
         amt_open_after_45 TYPE wrbtr,
         reason            TYPE char50,
         "color             TYPE slis_t_specialcol_alv,
       END OF ty_total.


DATA : lt_paid_invoice   TYPE STANDARD TABLE OF ty_result,
       lt_unpaid_invoice TYPE STANDARD TABLE OF ty_result,
       lt_unpaid         TYPE STANDARD TABLE OF ty_result,
       lt_final_paid     TYPE STANDARD TABLE OF ty_result,
       lt_total          TYPE STANDARD TABLE OF ty_total,
       lt_items          TYPE TABLE OF BAPI3008_2,
       "wa_item           TYPE BAPI3008_2,
*       wa_total          TYPE your_total_structure, " Replace with your actual structure name
*       lt_total          TYPE TABLE OF your_total_structure,
       lv_amt            TYPE wrbtr,
       lv_days_out       TYPE i,
       iv_temp           TYPE lifnr.




DATA: wa_total TYPE ty_total,
      "iv_temp  TYPE lifnr,
      iv_count TYPE i.
