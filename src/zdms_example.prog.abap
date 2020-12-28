*&---------------------------------------------------------------------*
*& Report  ZDMS_EXAMPLE
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT zdms_example.

DATA: lo_dms      TYPE REF TO zcl_dms,
      lv_aufnr    TYPE caufv-aufnr,
      lv_stlty    TYPE stko-stlty,
      lr_dokar    TYPE dms_tbl_rangesdokar,
      lv_dokst    TYPE draw-dokst,
      ls_draw     TYPE draw,
      lv_descript TYPE drat-dktxt,
      lt_files    TYPE zcvapi_doc_file_t.

FIELD-SYMBOLS <dokar> LIKE LINE OF lr_dokar.

* Busca ordem
SELECT SINGLE aufnr
  FROM caufv
  INTO lv_aufnr.

* Categoria da lista técnica
lv_stlty = 'M'. "Lista técnica de material

* Ranges
APPEND INITIAL LINE TO lr_dokar ASSIGNING <dokar>.
<dokar>-sign   = 'I'.
<dokar>-option = 'EQ'.
<dokar>-low    = 'OPF'.

* Cria objeto
CREATE OBJECT lo_dms
  EXPORTING
    i_aufnr                  = lv_aufnr  " Nº ordem
    i_stlty                  = lv_stlty  " Categoria da lista técnica
    i_dokar                  = lr_dokar  " Categoria de tabela ranges para tipo de documento
  EXCEPTIONS
    order_not_found          = 1
    technical_list_not_found = 2
    dms_not_found            = 3
    OTHERS                   = 4.
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
             WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.

* Busca DMS Atual
lv_dokst = 'AP'.

lo_dms->get_current(
  EXPORTING
    i_dokst       = lv_dokst    " Status documento
  IMPORTING
    e_draw        = ls_draw     " Registro info de documento
    e_description = lv_descript " Descrição documento
    e_files       = lt_files    " SAD: originais de um documento
).
