@EndUserText.label: 'Service Request Comment - Projection View'
@AccessControl.authorizationCheck: #CHECK

@Metadata.allowExtensions: true

define view entity ZC_SRT_Comment
  as projection on ZR_SRT_Comment

{
  key CommentUUID,

      RequestUUID,

      CommentText,

      CreatedBy,

      CreatedAt,

      LocalLastChangedAt,

      /* Associations */
      _Request : redirected to parent ZC_SRT_Request
}
