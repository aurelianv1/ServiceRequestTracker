INTERFACE zif_srt_constants
  PUBLIC.

  CONSTANTS:
    BEGIN OF status,
      new         TYPE c LENGTH 1 VALUE 'N',
      in_progress TYPE c LENGTH 1 VALUE 'P',
      escalated   TYPE c LENGTH 1 VALUE 'E',
      closed      TYPE c LENGTH 1 VALUE 'C',
    END OF status.

  CONSTANTS:
    BEGIN OF priority,
      critical TYPE c LENGTH 1 VALUE '1',
      high     TYPE c LENGTH 1 VALUE '2',
      medium   TYPE c LENGTH 1 VALUE '3',
      low      TYPE c LENGTH 1 VALUE '4',
    END OF priority.

ENDINTERFACE.
