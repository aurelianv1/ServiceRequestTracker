CLASS ltc_request DEFINITION DEFERRED FOR TESTING.
CLASS lhc_request DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_request.

  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Request RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Request RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Request RESULT result.

    METHODS closeRequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~closeRequest RESULT result.
    METHODS reopenRequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~reopenRequest RESULT result.
    METHODS escalateRequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~escalateRequest RESULT result.
    METHODS assignToMe FOR MODIFY
      IMPORTING keys FOR ACTION Request~assignToMe RESULT result.

    METHODS setRequestID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Request~setRequestID.
    METHODS determineStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~determineStatus.
    METHODS calculatePriority FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~calculatePriority.

    METHODS validateTitle FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateTitle.
    METHODS validateDueDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateDueDate.

ENDCLASS.

CLASS lhc_request IMPLEMENTATION.

  METHOD get_instance_features.
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status AssignedTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests)
      FAILED failed.

    result = VALUE #( FOR request IN requests
                      LET is_closed    = xsdbool( request-Status = zif_srt_constants=>status-closed )
                          is_escalated = xsdbool( request-Status = zif_srt_constants=>status-escalated )
                          is_mine      = xsdbool( request-AssignedTo = current_user )
                      IN
                      ( %tky                    = request-%tky
                        %action-closeRequest    = COND #( WHEN is_closed = abap_true
                                                          THEN if_abap_behv=>fc-o-disabled
                                                          ELSE if_abap_behv=>fc-o-enabled )
                        %action-reopenRequest   = COND #( WHEN is_closed = abap_true
                                                          THEN if_abap_behv=>fc-o-enabled
                                                          ELSE if_abap_behv=>fc-o-disabled )
                        %action-escalateRequest = COND #( WHEN is_closed = abap_true OR is_escalated = abap_true
                                                          THEN if_abap_behv=>fc-o-disabled
                                                          ELSE if_abap_behv=>fc-o-enabled )
                        %action-assignToMe      = COND #( WHEN is_closed = abap_true OR is_mine = abap_true
                                                          THEN if_abap_behv=>fc-o-disabled
                                                          ELSE if_abap_behv=>fc-o-enabled )
                        "A closed request is read-only until it is reopened
                        %action-Edit            = COND #( WHEN is_closed = abap_true
                                                          THEN if_abap_behv=>fc-o-disabled
                                                          ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    "No custom authorization object in this demo: every user of the app may
    "create, change and delete requests. Ownership rules are checked per instance.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( CreatedBy )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests)
      FAILED failed.

    LOOP AT requests INTO DATA(request).
      "Only the requester may delete a request; everybody may work on it
      DATA(may_delete) = xsdbool( request-CreatedBy IS INITIAL OR request-CreatedBy = current_user ).

      APPEND VALUE #( %tky         = request-%tky
                      %update      = if_abap_behv=>auth-allowed
                      %action-Edit = if_abap_behv=>auth-allowed
                      %delete      = COND #( WHEN may_delete = abap_true
                                             THEN if_abap_behv=>auth-allowed
                                             ELSE if_abap_behv=>auth-unauthorized ) )
        TO result.

      IF may_delete = abap_false AND requested_authorizations-%delete = if_abap_behv=>mk-on.
        APPEND VALUE #( %tky = request-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Only the requester ({ request-CreatedBy }) can delete this request| ) )
          TO reported-request.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD closeRequest.
    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky   = key-%tky
                                        Status = zif_srt_constants=>status-closed ) ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests ( %tky   = request-%tky
                                                %param = request ) ).
  ENDMETHOD.

  METHOD reopenRequest.
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( AssignedTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR request IN requests
                      ( %tky   = request-%tky
                        Status = COND #( WHEN request-AssignedTo IS INITIAL
                                         THEN zif_srt_constants=>status-new
                                         ELSE zif_srt_constants=>status-in_progress ) ) ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT requests.

    result = VALUE #( FOR request IN requests ( %tky   = request-%tky
                                                %param = request ) ).
  ENDMETHOD.

  METHOD escalateRequest.
    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status Priority )
        WITH VALUE #( FOR key IN keys ( %tky     = key-%tky
                                        Status   = zif_srt_constants=>status-escalated
                                        Priority = zif_srt_constants=>priority-critical ) ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    result = VALUE #( FOR request IN requests ( %tky   = request-%tky
                                                %param = request ) ).
  ENDMETHOD.

  METHOD assignToMe.
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( AssignedTo Status )
        WITH VALUE #( FOR request IN requests
                      ( %tky       = request-%tky
                        AssignedTo = current_user
                        "An escalated request stays escalated
                        Status     = COND #( WHEN request-Status = zif_srt_constants=>status-escalated
                                             THEN request-Status
                                             ELSE zif_srt_constants=>status-in_progress ) ) ).

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT requests.

    result = VALUE #( FOR request IN requests ( %tky   = request-%tky
                                                %param = request ) ).
  ENDMETHOD.

  METHOD setRequestID.
    "Ensure idempotence
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( RequestID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    DELETE requests WHERE RequestID IS NOT INITIAL.
    CHECK requests IS NOT INITIAL.

    SELECT SINGLE FROM zsrt_request FIELDS MAX( request_id ) INTO @DATA(max_request_id).

    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( RequestID )
        WITH VALUE #( FOR request IN requests INDEX INTO i
                      ( %tky      = request-%tky
                        RequestID = max_request_id + i ) ).
  ENDMETHOD.

  METHOD determineStatus.
    DATA requests_for_update TYPE TABLE FOR UPDATE zr_srt_request\\Request.

    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Status AssignedTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    "Escalated and closed requests are only changed by their actions
    DELETE requests WHERE Status = zif_srt_constants=>status-escalated
                       OR Status = zif_srt_constants=>status-closed.

    LOOP AT requests INTO DATA(request).
      DATA(new_status) = COND #( WHEN request-AssignedTo IS INITIAL
                                 THEN zif_srt_constants=>status-new
                                 ELSE zif_srt_constants=>status-in_progress ).
      IF new_status <> request-Status.
        APPEND VALUE #( %tky   = request-%tky
                        Status = new_status ) TO requests_for_update.
      ENDIF.
    ENDLOOP.

    CHECK requests_for_update IS NOT INITIAL.

    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Status )
        WITH requests_for_update.
  ENDMETHOD.

  METHOD calculatePriority.
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( DueDate Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    "An escalated request keeps its critical priority
    DELETE requests WHERE Status = zif_srt_constants=>status-escalated.
    CHECK requests IS NOT INITIAL.

    DATA(calculator) = NEW zcl_srt_priority_calculator( ).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( Priority )
        WITH VALUE #( FOR request IN requests
                      ( %tky     = request-%tky
                        Priority = calculator->calculate( due_date = request-DueDate
                                                          today    = today ) ) ).
  ENDMETHOD.

  METHOD validateTitle.
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( Title )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).
      APPEND VALUE #( %tky        = request-%tky
                      %state_area = 'VALIDATE_TITLE' ) TO reported-request.

      IF request-Title IS INITIAL.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        APPEND VALUE #( %tky           = request-%tky
                        %state_area    = 'VALIDATE_TITLE'
                        %msg           = new_message_with_text(
                                           severity = if_abap_behv_message=>severity-error
                                           text     = 'Enter a title for the request' )
                        %element-Title = if_abap_behv=>mk-on ) TO reported-request.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDueDate.
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Request
        FIELDS ( DueDate CreatedAt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(requests).

    LOOP AT requests INTO DATA(request).
      APPEND VALUE #( %tky        = request-%tky
                      %state_area = 'VALIDATE_DUE_DATE' ) TO reported-request.

      DATA(created_on) = cl_abap_context_info=>get_system_date( ).
      IF request-CreatedAt IS NOT INITIAL.
        CONVERT TIME STAMP request-CreatedAt TIME ZONE 'UTC' INTO DATE created_on.
      ENDIF.

      IF request-DueDate IS INITIAL.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        APPEND VALUE #( %tky             = request-%tky
                        %state_area      = 'VALIDATE_DUE_DATE'
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = 'Enter a due date for the request' )
                        %element-DueDate = if_abap_behv=>mk-on ) TO reported-request.
      ELSEIF request-DueDate < created_on.
        APPEND VALUE #( %tky = request-%tky ) TO failed-request.
        APPEND VALUE #( %tky             = request-%tky
                        %state_area      = 'VALIDATE_DUE_DATE'
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = |Due date { request-DueDate DATE = USER } is before | &&
                                                        |the creation date { created_on DATE = USER }| )
                        %element-DueDate = if_abap_behv=>mk-on ) TO reported-request.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lhc_comment DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_request.

  PRIVATE SECTION.

    METHODS validateCommentText FOR VALIDATE ON SAVE
      IMPORTING keys FOR Comment~validateCommentText.

ENDCLASS.

CLASS lhc_comment IMPLEMENTATION.

  METHOD validateCommentText.
    READ ENTITIES OF zr_srt_request IN LOCAL MODE
      ENTITY Comment
        FIELDS ( CommentText RequestUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(comments).

    LOOP AT comments INTO DATA(comment).
      APPEND VALUE #( %tky        = comment-%tky
                      %state_area = 'VALIDATE_COMMENT_TEXT' ) TO reported-comment.

      IF comment-CommentText IS INITIAL.
        APPEND VALUE #( %tky = comment-%tky ) TO failed-comment.
        APPEND VALUE #( %tky                 = comment-%tky
                        %state_area          = 'VALIDATE_COMMENT_TEXT'
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'A comment must not be empty' )
                        %path                = VALUE #( request-%is_draft   = comment-%is_draft
                                                        request-RequestUUID = comment-RequestUUID )
                        %element-CommentText = if_abap_behv=>mk-on ) TO reported-comment.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
