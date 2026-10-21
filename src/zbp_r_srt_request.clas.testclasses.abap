"! @testing BDEF:ZR_SRT_Request
CLASS ltc_request DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CONSTANTS:
      uuid1 TYPE sysuuid_x16 VALUE '5A1C0F2E9B3D4E6F8A7B6C5D4E3F2A01',
      uuid2 TYPE sysuuid_x16 VALUE '5A1C0F2E9B3D4E6F8A7B6C5D4E3F2A02',
      uuid3 TYPE sysuuid_x16 VALUE '5A1C0F2E9B3D4E6F8A7B6C5D4E3F2A03',
      uuid4 TYPE sysuuid_x16 VALUE '5A1C0F2E9B3D4E6F8A7B6C5D4E3F2A04'.

    CLASS-DATA:
      request_handler      TYPE REF TO lhc_request,
      comment_handler      TYPE REF TO lhc_comment,
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      "! Instantiate the handlers and set up the test doubles
      class_setup,
      "! Destroy the test doubles
      class_teardown.

    METHODS:
      "! Reset test doubles and fill the priority configuration
      setup,
      "! Reset the transactional buffer
      teardown.

    METHODS:
      "! { @link ..lhc_request.METH:setRequestID } continues after the highest existing ID
      "! and leaves requests that already have an ID untouched.
      set_request_id_draws_next    FOR TESTING,

      "! { @link ..lhc_request.METH:determineStatus } derives New / In Progress from the
      "! assignee and never touches escalated requests.
      status_follows_assignee      FOR TESTING,

      "! { @link ..lhc_request.METH:calculatePriority } uses the configured thresholds
      "! and keeps the critical priority of escalated requests.
      priority_from_due_date       FOR TESTING,

      "! { @link ..lhc_request.METH:validateTitle } rejects a request without title.
      validate_title_missing       FOR TESTING,

      "! { @link ..lhc_request.METH:validateDueDate } rejects a due date before the creation
      "! date and accepts one after it.
      validate_due_date            FOR TESTING,

      "! { @link ..lhc_request.METH:closeRequest } closes the request and returns it.
      close_request                FOR TESTING,

      "! { @link ..lhc_request.METH:escalateRequest } sets status Escalated and priority Critical.
      escalate_request             FOR TESTING,

      "! { @link ..lhc_request.METH:get_instance_features } makes closed requests read-only
      "! and only offers Reopen for them.
      features_by_status           FOR TESTING,

      "! { @link ..lhc_comment.METH:validateCommentText } rejects an empty comment.
      validate_empty_comment       FOR TESTING.

ENDCLASS.


CLASS ltc_request IMPLEMENTATION.

  METHOD class_setup.
    CREATE OBJECT request_handler FOR TESTING.
    CREATE OBJECT comment_handler FOR TESTING.

    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
                               VALUE #( ( i_for_entity = 'ZR_SRT_REQUEST' )
                                        ( i_for_entity = 'ZR_SRT_COMMENT' ) ) ).
    cds_test_environment->enable_double_redirection( ).

    sql_test_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZSRT_PRIORITY' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    cds_test_environment->destroy( ).
    sql_test_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA priorities TYPE STANDARD TABLE OF zsrt_priority WITH EMPTY KEY.

    cds_test_environment->clear_doubles( ).
    sql_test_environment->clear_doubles( ).

    priorities = VALUE #( ( priority = zif_srt_constants=>priority-critical max_days = 0 )
                          ( priority = zif_srt_constants=>priority-high     max_days = 2 )
                          ( priority = zif_srt_constants=>priority-medium   max_days = 7 )
                          ( priority = zif_srt_constants=>priority-low      max_days = 9999 ) ).
    sql_test_environment->insert_test_data( priorities ).
  ENDMETHOD.


  METHOD teardown.
    ROLLBACK ENTITIES.                                 "#EC CI_ROLLBACK
  ENDMETHOD.


  METHOD set_request_id_draws_next.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1  request_id = '0000000005' )
                                 ( request_uuid = uuid2 )
                                 ( request_uuid = uuid3 ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->setrequestid(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 ) ( RequestUUID = uuid3 ) )
        CHANGING
          reported = reported ).

    cl_abap_unit_assert=>assert_initial( reported ).

    READ ENTITIES OF zr_srt_request
      ENTITY Request
        FIELDS ( RequestID )
        WITH VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 ) ( RequestUUID = uuid3 ) )
      RESULT DATA(requests).

    SORT requests BY RequestID.

    cl_abap_unit_assert=>assert_equals( exp = 3  act = lines( requests ) ).
    cl_abap_unit_assert=>assert_equals( exp = '0000000005'  act = requests[ 1 ]-RequestID ).
    cl_abap_unit_assert=>assert_equals( exp = '0000000006'  act = requests[ 2 ]-RequestID ).
    cl_abap_unit_assert=>assert_equals( exp = '0000000007'  act = requests[ 3 ]-RequestID ).
  ENDMETHOD.


  METHOD status_follows_assignee.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    request_mock_data = VALUE #(
        ( request_uuid = uuid1 )
        ( request_uuid = uuid2  assigned_to = 'DEVELOPER' )
        ( request_uuid = uuid3  assigned_to = 'DEVELOPER'  status = zif_srt_constants=>status-escalated )
        ( request_uuid = uuid4  status = zif_srt_constants=>status-in_progress ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->determinestatus(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 )
                              ( RequestUUID = uuid3 ) ( RequestUUID = uuid4 ) )
        CHANGING
          reported = reported ).

    cl_abap_unit_assert=>assert_initial( reported ).

    READ ENTITIES OF zr_srt_request
      ENTITY Request
        FIELDS ( Status )
        WITH VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 )
                      ( RequestUUID = uuid3 ) ( RequestUUID = uuid4 ) )
      RESULT DATA(requests).

    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-new
                                        act = requests[ RequestUUID = uuid1 ]-Status ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-in_progress
                                        act = requests[ RequestUUID = uuid2 ]-Status ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-escalated
                                        act = requests[ RequestUUID = uuid3 ]-Status ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-new
                                        act = requests[ RequestUUID = uuid4 ]-Status ).
  ENDMETHOD.


  METHOD priority_from_due_date.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    request_mock_data = VALUE #(
        ( request_uuid = uuid1  due_date = today + 1 )
        ( request_uuid = uuid2  due_date = today + 5 )
        ( request_uuid = uuid3  due_date = today + 30 )
        ( request_uuid = uuid4  due_date = today + 30
          status = zif_srt_constants=>status-escalated  priority = zif_srt_constants=>priority-critical ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->calculatepriority(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 )
                              ( RequestUUID = uuid3 ) ( RequestUUID = uuid4 ) )
        CHANGING
          reported = reported ).

    READ ENTITIES OF zr_srt_request
      ENTITY Request
        FIELDS ( Priority )
        WITH VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 )
                      ( RequestUUID = uuid3 ) ( RequestUUID = uuid4 ) )
      RESULT DATA(requests).

    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>priority-high
                                        act = requests[ RequestUUID = uuid1 ]-Priority ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>priority-medium
                                        act = requests[ RequestUUID = uuid2 ]-Priority ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>priority-low
                                        act = requests[ RequestUUID = uuid3 ]-Priority ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>priority-critical
                                        act = requests[ RequestUUID = uuid4 ]-Priority ).
  ENDMETHOD.


  METHOD validate_title_missing.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      failed            TYPE RESPONSE FOR FAILED LATE zr_srt_request,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1 )
                                 ( request_uuid = uuid2  title = 'Printer on floor 3 is jammed' ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->validatetitle(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 ) )
        CHANGING
          failed   = failed
          reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 1  act = lines( failed-request ) ).
    cl_abap_unit_assert=>assert_equals( exp = uuid1  act = failed-request[ 1 ]-RequestUUID ).

    "One state-area reset per request plus one error message
    cl_abap_unit_assert=>assert_equals( exp = 3  act = lines( reported-request ) ).
    LOOP AT reported-request INTO DATA(message) WHERE %msg IS BOUND.
      cl_abap_unit_assert=>assert_equals( exp = uuid1  act = message-RequestUUID ).
      cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>mk-on  act = message-%element-Title ).
    ENDLOOP.
  ENDMETHOD.


  METHOD validate_due_date.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      failed            TYPE RESPONSE FOR FAILED LATE zr_srt_request,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    "Created on 2026-10-01
    request_mock_data = VALUE #(
        ( request_uuid = uuid1  created_at = '20261001120000.0000000'  due_date = '20260930' )
        ( request_uuid = uuid2  created_at = '20261001120000.0000000'  due_date = '20261001' )
        ( request_uuid = uuid3  created_at = '20261001120000.0000000'  due_date = '20261015' )
        ( request_uuid = uuid4  created_at = '20261001120000.0000000' ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->validateduedate(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 )
                              ( RequestUUID = uuid3 ) ( RequestUUID = uuid4 ) )
        CHANGING
          failed   = failed
          reported = reported ).

    SORT failed-request BY RequestUUID.
    cl_abap_unit_assert=>assert_equals( exp = 2  act = lines( failed-request ) ).
    cl_abap_unit_assert=>assert_equals( exp = uuid1  act = failed-request[ 1 ]-RequestUUID ).
    cl_abap_unit_assert=>assert_equals( exp = uuid4  act = failed-request[ 2 ]-RequestUUID ).
  ENDMETHOD.


  METHOD close_request.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      result            TYPE TABLE FOR ACTION RESULT zr_srt_request\\Request~closeRequest,
      mapped            TYPE RESPONSE FOR MAPPED EARLY zr_srt_request,
      failed            TYPE RESPONSE FOR FAILED EARLY zr_srt_request,
      reported          TYPE RESPONSE FOR REPORTED EARLY zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1  status = zif_srt_constants=>status-in_progress ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->closerequest(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) )
        CHANGING
          result   = result
          mapped   = mapped
          failed   = failed
          reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals( exp = 1  act = lines( result ) ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-closed
                                        act = result[ 1 ]-%param-Status ).
  ENDMETHOD.


  METHOD escalate_request.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      result            TYPE TABLE FOR ACTION RESULT zr_srt_request\\Request~escalateRequest,
      mapped            TYPE RESPONSE FOR MAPPED EARLY zr_srt_request,
      failed            TYPE RESPONSE FOR FAILED EARLY zr_srt_request,
      reported          TYPE RESPONSE FOR REPORTED EARLY zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1
                                   status       = zif_srt_constants=>status-new
                                   priority     = zif_srt_constants=>priority-low ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->escalaterequest(
        EXPORTING
          keys     = VALUE #( ( RequestUUID = uuid1 ) )
        CHANGING
          result   = result
          mapped   = mapped
          failed   = failed
          reported = reported ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>status-escalated
                                        act = result[ 1 ]-%param-Status ).
    cl_abap_unit_assert=>assert_equals( exp = zif_srt_constants=>priority-critical
                                        act = result[ 1 ]-%param-Priority ).
  ENDMETHOD.


  METHOD features_by_status.
    DATA:
      request_mock_data  TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      requested_features TYPE STRUCTURE FOR INSTANCE FEATURES REQUEST zr_srt_request\\Request,
      result             TYPE TABLE FOR INSTANCE FEATURES RESULT zr_srt_request\\Request,
      failed             TYPE RESPONSE FOR FAILED EARLY zr_srt_request,
      reported           TYPE RESPONSE FOR REPORTED EARLY zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1  status = zif_srt_constants=>status-closed )
                                 ( request_uuid = uuid2  status = zif_srt_constants=>status-new ) ).
    cds_test_environment->insert_test_data( request_mock_data ).

    request_handler->get_instance_features(
        EXPORTING
          keys               = VALUE #( ( RequestUUID = uuid1 ) ( RequestUUID = uuid2 ) )
          requested_features = requested_features
        CHANGING
          result             = result
          failed             = failed
          reported           = reported ).

    cl_abap_unit_assert=>assert_initial( failed ).

    DATA(closed_request) = result[ RequestUUID = uuid1 ].
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled  act = closed_request-%action-closeRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-enabled   act = closed_request-%action-reopenRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled  act = closed_request-%action-escalateRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled  act = closed_request-%action-assignToMe ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled  act = closed_request-%action-Edit ).

    DATA(open_request) = result[ RequestUUID = uuid2 ].
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-enabled   act = open_request-%action-closeRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-disabled  act = open_request-%action-reopenRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-enabled   act = open_request-%action-escalateRequest ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-enabled   act = open_request-%action-assignToMe ).
    cl_abap_unit_assert=>assert_equals( exp = if_abap_behv=>fc-o-enabled   act = open_request-%action-Edit ).
  ENDMETHOD.


  METHOD validate_empty_comment.
    DATA:
      request_mock_data TYPE STANDARD TABLE OF zsrt_request WITH EMPTY KEY,
      comment_mock_data TYPE STANDARD TABLE OF zsrt_comment WITH EMPTY KEY,
      failed            TYPE RESPONSE FOR FAILED LATE zr_srt_request,
      reported          TYPE RESPONSE FOR REPORTED LATE zr_srt_request.

    request_mock_data = VALUE #( ( request_uuid = uuid1 ) ).
    comment_mock_data = VALUE #( ( comment_uuid = uuid2  request_uuid = uuid1 )
                                 ( comment_uuid = uuid3  request_uuid = uuid1  comment_text = 'Technician is on the way' ) ).
    cds_test_environment->insert_test_data( request_mock_data ).
    cds_test_environment->insert_test_data( comment_mock_data ).

    comment_handler->validatecommenttext(
        EXPORTING
          keys     = VALUE #( ( CommentUUID = uuid2 ) ( CommentUUID = uuid3 ) )
        CHANGING
          failed   = failed
          reported = reported ).

    cl_abap_unit_assert=>assert_equals( exp = 1  act = lines( failed-comment ) ).
    cl_abap_unit_assert=>assert_equals( exp = uuid2  act = failed-comment[ 1 ]-CommentUUID ).
  ENDMETHOD.

ENDCLASS.
