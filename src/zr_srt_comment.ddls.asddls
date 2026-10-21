@EndUserText.label: 'Service Request Comment - View Entity'
@AccessControl.authorizationCheck: #CHECK

define view entity ZR_SRT_Comment
  as select from zsrt_comment

  association to parent ZR_SRT_Request as _Request on $projection.RequestUUID = _Request.RequestUUID

{
  key comment_uuid          as CommentUUID,

      request_uuid          as RequestUUID,

      @EndUserText.label: 'Comment'
      comment_text          as CommentText,

      @EndUserText.label: 'Author'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Posted At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      //local ETag field --> OData ETag
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Request
}
