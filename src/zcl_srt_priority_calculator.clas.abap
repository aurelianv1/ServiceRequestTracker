CLASS zcl_srt_priority_calculator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_priority TYPE c LENGTH 1.

    "! Derives the priority of a service request from the number of days
    "! left until its due date, using the thresholds of table ZSRT_PRIORITY.
    "! Critical is never derived - only the Escalate action sets it.
    METHODS calculate
      IMPORTING due_date        TYPE d
                today           TYPE d
      RETURNING VALUE(priority) TYPE ty_priority.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_threshold,
        priority TYPE ty_priority,
        max_days TYPE i,
      END OF ty_threshold,
      ty_thresholds TYPE STANDARD TABLE OF ty_threshold WITH EMPTY KEY.

    DATA thresholds TYPE ty_thresholds.

    METHODS load_thresholds.

ENDCLASS.



CLASS zcl_srt_priority_calculator IMPLEMENTATION.

  METHOD calculate.
    IF due_date IS INITIAL.
      priority = zif_srt_constants=>priority-medium.
      RETURN.
    ENDIF.

    IF thresholds IS INITIAL.
      load_thresholds( ).
    ENDIF.

    DATA(days_left) = due_date - today.

    "Thresholds are sorted ascending, so the first match is the most urgent one
    LOOP AT thresholds INTO DATA(threshold) WHERE max_days >= days_left.
      priority = threshold-priority.
      RETURN.
    ENDLOOP.

    priority = zif_srt_constants=>priority-low.
  ENDMETHOD.


  METHOD load_thresholds.
    SELECT FROM zsrt_priority
      FIELDS priority, max_days
      WHERE priority <> @zif_srt_constants=>priority-critical
      ORDER BY max_days
      INTO TABLE @thresholds.

    IF thresholds IS INITIAL.
      "Fallback as long as the configuration table has not been filled
      thresholds = VALUE #( ( priority = zif_srt_constants=>priority-high   max_days = 2 )
                            ( priority = zif_srt_constants=>priority-medium max_days = 7 ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
