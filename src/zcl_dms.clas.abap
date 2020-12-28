class ZCL_DMS definition
  public
  final
  create public .

public section.

  constants GC_CLASS_MESSAGE type ARBGB value 'ZDMS'. "#EC NOTEXT

  methods CONSTRUCTOR
    importing
      !I_AUFNR type CAUFV-AUFNR
      !I_STLTY type STKO-STLTY
    exceptions
      ORDER_NOT_FOUND
      TECHNICAL_LIST_NOT_FOUND
      DMS_NOT_FOUND .
  methods GET_CURRENT
    importing
      !I_DOKST type DRAW-DOKST optional
    exporting
      !E_DRAW type DRAW
      !E_DESCRIPTION type DRAT-DKTXT
      !E_FILES type ZCVAPI_DOC_FILE_T .
  methods GET_BY_CONFIRMATION_DATE
    importing
      !I_DOKST type DRAW-DOKST
    returning
      value(E_DOCUMENTS) type DMS_TBL_DRAW .
  methods GET_BY_STATUS
    importing
      !I_DOKST type DRAW-DOKST optional
    returning
      value(E_DOCUMENTS) type DMS_TBL_DRAW .
  methods GET_FILES
    importing
      !I_DRAW type DRAW
    returning
      value(E_FILES) type ZCVAPI_DOC_FILE_T .
  methods GET_DESCRIPTION
    importing
      !I_DRAW type DRAW
    returning
      value(E_DKTXT) type DKTXT .
protected section.
private section.

  types:
    BEGIN OF ty_caufv,
          aufnr TYPE caufv-aufnr,
          stlnr TYPE caufv-stlnr,
          stlal TYPE caufv-stlal,
          ftrmi TYPE caufv-ftrmi,
         END OF ty_caufv .
  types:
    BEGIN OF ty_stko,
                 stlty TYPE stko-stlty,
                 stlnr TYPE stko-stlnr,
                 stlal TYPE stko-stlal,
                 stkoz TYPE stko-stkoz,
                 guidx TYPE stko-guidx,
                END OF ty_stko .

  data:
    gr_dokar TYPE RANGE OF draw-dokar .
  data GS_CAUFV type TY_CAUFV .
  data GS_STKO type TY_STKO .
  data GT_DRAD type DMS_TBL_DRAD .
  data GT_DRAW type DMS_TBL_DRAW .
ENDCLASS.



CLASS ZCL_DMS IMPLEMENTATION.


METHOD constructor.

  FIELD-SYMBOLS: <dokar> LIKE LINE OF gr_dokar.

* Ranges
  APPEND INITIAL LINE TO gr_dokar ASSIGNING <dokar>.
  <dokar>-sign   = 'I'.
  <dokar>-option = 'EQ'.
  <dokar>-low    = 'ZIF'.

* Obtém lista técnica (bill of material) e alternativa (alternative)
  SELECT SINGLE aufnr stlnr stlal ftrmi
    FROM caufv
    INTO gs_caufv
    WHERE aufnr = i_aufnr.
  IF sy-subrc <> 0.
    sy-msgty = 'E'.
    sy-msgid = gc_class_message.
    sy-msgno = '001'.
    sy-msgv1 = i_aufnr.
    RAISE order_not_found.
  ENDIF.

* Obtém cabeçalho da lista técnica
  SELECT SINGLE stlty stlnr stlal stkoz guidx
    FROM stko
    INTO gs_stko
    WHERE stlty = i_stlty "Lista técnica de material
      AND stlnr = gs_caufv-stlnr
      AND stlal = gs_caufv-stlal.
  IF sy-subrc <> 0.
    sy-msgty = 'E'.
    sy-msgid = gc_class_message.
    sy-msgno = '002'.
    sy-msgv1 = gs_caufv-stlnr.
    RAISE technical_list_not_found.
  ENDIF.

* Busca ligações de documento
  SELECT *
    FROM drad
    INTO TABLE gt_drad
    WHERE dokar IN gr_dokar
      AND dokob = 'STKO_DOC'
      AND objky = gs_stko-guidx.

* Busca cabeçalho documento DMS
  SELECT *
    FROM draw
    INTO TABLE gt_draw
    FOR ALL ENTRIES IN gt_drad
    WHERE dokar = gt_drad-dokar
      AND doknr = gt_drad-doknr
      AND dokvr = gt_drad-dokvr
      AND doktl = gt_drad-doktl.
  IF sy-subrc <> 0.
    sy-msgty = 'E'.
    sy-msgid = gc_class_message.
    sy-msgno = '003'.
    RAISE dms_not_found.
  ENDIF.

ENDMETHOD.


METHOD get_by_confirmation_date.
* Para cada DMS encontrado com base na lista técnica, verifica a data do status informado comparando com a data de confirmação da ordem
* se a data for menor ou igual a data de confirmação da ordem então retorna o documento.

  DATA: lt_drap  TYPE TABLE OF drap,
        lv_valid TYPE flag.

  FIELD-SYMBOLS: <draw> LIKE LINE OF gt_draw,
                 <drap> LIKE LINE OF lt_drap,
                 <document> LIKE LINE OF e_documents.

  SELECT *
    FROM drap
    INTO TABLE lt_drap
    FOR ALL ENTRIES IN gt_draw
    WHERE dokar = gt_draw-dokar
      AND doknr = gt_draw-doknr
      AND dokvr = gt_draw-dokvr
      AND doktl = gt_draw-doktl
      AND dokst = i_dokst
      AND datum <= gs_caufv-ftrmi.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  SORT lt_drap BY datum DESCENDING.

  READ TABLE lt_drap ASSIGNING <drap> INDEX 1.
  READ TABLE gt_draw ASSIGNING <draw> WITH KEY dokar = <drap>-dokar
                                               doknr = <drap>-doknr
                                               dokvr = <drap>-dokvr
                                               doktl = <drap>-doktl.
  IF sy-subrc = 0.

    APPEND INITIAL LINE TO e_documents ASSIGNING <document>.
    <document> = <draw>.

  ENDIF.

ENDMETHOD.


METHOD get_by_status.

  e_documents = gt_draw.
  DELETE e_documents WHERE dokst <> i_dokst.

ENDMETHOD.


METHOD get_current.

  DATA: lt_draw TYPE TABLE OF draw.
  FIELD-SYMBOLS: <draw> LIKE LINE OF lt_draw.

  lt_draw = gt_draw.

* Filter by document status
  IF i_dokst IS NOT INITIAL.
    DELETE lt_draw WHERE dokst <> i_dokst.
    IF lines( lt_draw ) = 0.
      RETURN.
    ENDIF.
  ENDIF.

* Order by most current document
  SORT lt_draw BY adatum DESCENDING.
  READ TABLE lt_draw ASSIGNING <draw> INDEX 1.

* Return header
  e_draw = <draw>.

* Get description/files
  CALL FUNCTION 'CVAPI_DOC_GETDETAIL'
    EXPORTING
      pf_dokar        = <draw>-dokar
      pf_doknr        = <draw>-doknr
      pf_dokvr        = <draw>-dokvr
      pf_doktl        = <draw>-doktl
      pf_active_files = 'X'
    IMPORTING
      pfx_description = e_description
    TABLES
      pt_files        = e_files
    EXCEPTIONS
      not_found       = 1
      no_auth         = 2
      error           = 3
      OTHERS          = 4.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

ENDMETHOD.


METHOD get_description.

  SELECT SINGLE dktxt
    FROM drat
    INTO e_dktxt
    WHERE dokar = i_draw-dokar
      AND doknr = i_draw-doknr
      AND dokvr = i_draw-dokvr
      AND doktl = i_draw-doktl
      AND langu = sy-langu.

ENDMETHOD.


METHOD get_files.

* Get description/files
  CALL FUNCTION 'CVAPI_DOC_GETDETAIL'
    EXPORTING
      pf_dokar        = i_draw-dokar
      pf_doknr        = i_draw-doknr
      pf_dokvr        = i_draw-dokvr
      pf_doktl        = i_draw-doktl
      pf_active_files = 'X'
    TABLES
      pt_files        = e_files
    EXCEPTIONS
      not_found       = 1
      no_auth         = 2
      error           = 3
      OTHERS          = 4.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

ENDMETHOD.
ENDCLASS.
