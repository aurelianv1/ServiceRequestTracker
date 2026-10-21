@EndUserText.label: 'Service Request - Root View Entity'
@AccessControl.authorizationCheck: #CHECK

define root view entity ZR_SRT_Request
  as select from zsrt_request

  composition [0..*] of ZR_SRT_Comment     as _Comment

  association [0..1] to ZI_SRT_Priority_VH as _Priority on $projection.Priority = _Priority.Priority
  association [0..1] to ZI_SRT_Status_VH   as _Status   on $projection.Status = _Status.Status

{
  key request_uuid          as RequestUUID,

      @EndUserText.label: 'Request ID'
      request_id            as RequestID,

      @EndUserText.label: 'Title'
      title                 as Title,

      @EndUserText.label: 'Description'
      description           as Description,

      @EndUserText.label: 'Priority'
      priority              as Priority,

      @EndUserText.label: 'Status'
      status                as Status,

      @EndUserText.label: 'Assigned To'
      assigned_to           as AssignedTo,

      @EndUserText.label: 'Due Date'
      due_date              as DueDate,

      @EndUserText.label: 'Requested By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Last Changed By'
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,

      //total ETag field
      @EndUserText.label: 'Last Changed At'
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      //local ETag field --> OData ETag
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Comment,
      _Priority,
      _Status
}
