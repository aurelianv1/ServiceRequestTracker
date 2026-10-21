"! @testing ZCL_SRT_PRIORITY_CALCULATOR
CLASS ltc_priority_calculator DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS today TYPE d VALUE '20261001'.

    CLASS-DATA sql_test_environment TYPE REF TO if_osql_test_environment.

    DATA class_under_test TYPE REF TO zcl_srt_priority_calculator.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    "! Due tomorrow -> within the 'High' threshold of the configuration
    METHODS due_tomorrow_is_high FOR TESTING.
    "! Due in 5 days -> within the 'Medium' threshold of the configuration
    METHODS due_in_five_days_is_medium FOR TESTING.
    "! Due in a month -> 'Low'
    METHODS due_in_a_month_is_low FOR TESTING.
    "! Already overdue -> most urgent derivable priority, never 'Critical'
    METHODS overdue_is_high FOR TESTING.
    "! No due date maintained -> 'Medium'
    METHODS no_due_date_is_medium FOR TESTING.
    "! Empty configuration table -> built-in fallback thresholds are used
    METHODS fallback_without_config FOR TESTING.

ENDCLASS.


CLASS ltc_priority_calculator IMPLEMENTATION.

  METHOD class_setup.
    sql_test_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZSRT_PRIORITY' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    sql_test_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA priorities TYPE STANDARD TABLE OF zsrt_priority WITH EMPTY KEY.

    sql_test_environment->clear_doubles( ).

    "Thresholds deliberately differ from the delivered ones (2/7 days)
    "to prove that the configuration table is read
    priorities = VALUE #( ( priority = zif_srt_constants=>priority-critical max_days = 0 )
                          ( priority = zif_srt_constants=>priority-high     max_days = 1 )
                          ( priority = zif_srt_constants=>priority-medium   max_days = 5 )
                          ( priority = zif_srt_constants=>priority-low      max_days = 9999 ) ).
    sql_test_environment->insert_test_data( priorities ).

    class_under_test = NEW #( ).
  ENDMETHOD.


  METHOD due_tomorrow_is_high.
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-high
        act = class_under_test->calculate( due_date = CONV #( today + 1 )  today = today ) ).
  ENDMETHOD.


  METHOD due_in_five_days_is_medium.
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-medium
        act = class_under_test->calculate( due_date = CONV #( today + 5 )  today = today ) ).
  ENDMETHOD.


  METHOD due_in_a_month_is_low.
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-low
        act = class_under_test->calculate( due_date = CONV #( today + 30 )  today = today ) ).
  ENDMETHOD.


  METHOD overdue_is_high.
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-high
        act = class_under_test->calculate( due_date = CONV #( today - 3 )  today = today ) ).
  ENDMETHOD.


  METHOD no_due_date_is_medium.
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-medium
        act = class_under_test->calculate( due_date = '00000000'  today = today ) ).
  ENDMETHOD.


  METHOD fallback_without_config.
    sql_test_environment->clear_doubles( ).
    class_under_test = NEW #( ).

    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-high
        act = class_under_test->calculate( due_date = CONV #( today + 2 )  today = today ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-medium
        act = class_under_test->calculate( due_date = CONV #( today + 7 )  today = today ) ).
    cl_abap_unit_assert=>assert_equals(
        exp = zif_srt_constants=>priority-low
        act = class_under_test->calculate( due_date = CONV #( today + 8 )  today = today ) ).
  ENDMETHOD.

ENDCLASS.
