@EndUserText.label: 'Service Request - Projection View'
@AccessControl.authorizationCheck: #CHECK

@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['RequestID']

define root view entity ZC_SRT_Request
  provider contract transactional_query
  as projection on ZR_SRT_Request

{
  key RequestUUID,

      @Search.defaultSearchElement: true
      RequestID,

      @Search.defaultSearchElement: true
      Title,

      Description,

      @ObjectModel.text.element: ['PriorityText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_SRT_Priority_VH', element: 'Priority' } }]
      Priority,
      _Priority.PriorityText as PriorityText,
      _Priority.Criticality  as PriorityCriticality,

      @ObjectModel.text.element: ['StatusText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_SRT_Status_VH', element: 'Status' } }]
      Status,
      _Status.StatusText     as StatusText,
      _Status.Criticality    as StatusCriticality,

      @Search.defaultSearchElement: true
      AssignedTo,

      DueDate,

      @Search.defaultSearchElement: true
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _Comment : redirected to composition child ZC_SRT_Comment,
      _Priority,
      _Status
}
