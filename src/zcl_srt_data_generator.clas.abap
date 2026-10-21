"! Fills the configuration tables and creates demo service requests.
"! Run it with F9 (Run as ABAP Application - Console) after the first pull.
"! Existing requests are deleted, so the app always starts from the same state.
CLASS zcl_srt_data_generator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    METHODS fill_configuration
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS create_demo_requests
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.



CLASS zcl_srt_data_generator IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    fill_configuration( out ).
    create_demo_requests( out ).
  ENDMETHOD.


  METHOD fill_configuration.
    DATA priorities TYPE STANDARD TABLE OF zsrt_priority WITH EMPTY KEY.
    DATA statuses   TYPE STANDARD TABLE OF zsrt_status WITH EMPTY KEY.

    "Criticality: 0 neutral, 1 negative (red), 2 critical (orange), 3 positive (green), 5 information (blue)
    priorities = VALUE #( ( priority = zif_srt_constants=>priority-critical description = 'Critical' max_days = 0    criticality = 1 )
                          ( priority = zif_srt_constants=>priority-high     description = 'High'     max_days = 2    criticality = 2 )
                          ( priority = zif_srt_constants=>priority-medium   description = 'Medium'   max_days = 7    criticality = 0 )
                          ( priority = zif_srt_constants=>priority-low      description = 'Low'      max_days = 9999 criticality = 3 ) ).

    statuses = VALUE #( ( status = zif_srt_constants=>status-new         description = 'New'         criticality = 5 )
                        ( status = zif_srt_constants=>status-in_progress description = 'In Progress' criticality = 2 )
                        ( status = zif_srt_constants=>status-escalated   description = 'Escalated'   criticality = 1 )
                        ( status = zif_srt_constants=>status-closed      description = 'Closed'      criticality = 3 ) ).

    DELETE FROM zsrt_priority.                          "#EC CI_NOWHERE
    INSERT zsrt_priority FROM TABLE @priorities.
    DELETE FROM zsrt_status.                            "#EC CI_NOWHERE
    INSERT zsrt_status FROM TABLE @statuses.

    out->write( |Configuration: { lines( priorities ) } priorities, { lines( statuses ) } statuses| ).
  ENDMETHOD.


  METHOD create_demo_requests.
    DELETE FROM zsrt_d_comment.                         "#EC CI_NOWHERE
    DELETE FROM zsrt_d_request.                         "#EC CI_NOWHERE
    DELETE FROM zsrt_comment.                           "#EC CI_NOWHERE
    DELETE FROM zsrt_request.                           "#EC CI_NOWHERE
    COMMIT WORK.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    "Created through EML, so numbering, determinations and validations run as in the app
    MODIFY ENTITIES OF zr_srt_request
      ENTITY Request
        CREATE FIELDS ( Title Description DueDate AssignedTo )
        WITH VALUE #(
          ( %cid        = 'R1'
            Title       = 'Air conditioning not working in meeting room B2'
            Description = 'Room temperature is above 30 degrees, the unit only blows warm air.'
            DueDate     = today + 1
            AssignedTo  = 'TECH_ANNA' )
          ( %cid        = 'R2'
            Title       = 'Replace broken office chair at desk 4.12'
            Description = 'The gas lift is broken, the chair does not stay up.'
            DueDate     = today + 20 )
          ( %cid        = 'R3'
            Title       = 'Network outage on floor 3'
            Description = 'No LAN connection for the whole east wing since this morning.'
            DueDate     = today + 2
            AssignedTo  = 'TECH_MIHAI' )
          ( %cid        = 'R4'
            Title       = 'Projector bulb replacement in training room'
            Description = 'The image is very dark, the bulb warning light is on.'
            DueDate     = today + 5
            AssignedTo  = 'TECH_ANNA' )
          ( %cid        = 'R5'
            Title       = 'Water leak under kitchen sink'
            Description = 'Small leak at the siphon, a bucket has been placed under it.'
            DueDate     = today + 3 )
          ( %cid        = 'R6'
            Title       = 'Install new badge reader at main entrance'
            Description = 'The new reader has been delivered and is stored at the reception.'
            DueDate     = today + 45
            AssignedTo  = 'TECH_JOHN' ) )

        CREATE BY \_Comment
        FIELDS ( CommentText )
        WITH VALUE #(
          ( %cid_ref = 'R1'
            %target  = VALUE #( ( %cid = 'C1' CommentText = 'Checked the unit - the compressor needs to be replaced.' )
                                ( %cid = 'C2' CommentText = 'Spare part ordered, delivery expected tomorrow.' ) ) )
          ( %cid_ref = 'R3'
            %target  = VALUE #( ( %cid = 'C3' CommentText = 'Switch in rack 3A is down, vendor support has been called.' ) ) )
          ( %cid_ref = 'R4'
            %target  = VALUE #( ( %cid = 'C4' CommentText = 'Bulb replaced and projector tested - works fine.' ) ) ) )

      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed IS NOT INITIAL.
      out->write( |Creating the demo requests failed: { lines( failed-request ) } request(s) rejected| ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zr_srt_request
      FAILED DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      LOOP AT commit_reported-request INTO DATA(message) WHERE %msg IS BOUND.
        out->write( message-%msg->if_message~get_text( ) ).
      ENDLOOP.
      RETURN.
    ENDIF.

    "Bring two of the requests into a later state through the BO actions
    MODIFY ENTITIES OF zr_srt_request
      ENTITY Request
        EXECUTE escalateRequest FROM VALUE #( ( RequestUUID = mapped-request[ %cid = 'R3' ]-RequestUUID ) )
        EXECUTE closeRequest    FROM VALUE #( ( RequestUUID = mapped-request[ %cid = 'R4' ]-RequestUUID ) )
      FAILED failed
      REPORTED reported.

    COMMIT ENTITIES.

    SELECT FROM zsrt_request FIELDS request_id, title, priority, status
      ORDER BY request_id
      INTO TABLE @DATA(requests).

    out->write( |Demo data: { lines( requests ) } service requests created| ).
    out->write( requests ).
  ENDMETHOD.

ENDCLASS.
