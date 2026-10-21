@EndUserText.label: 'Service Request Status - Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZI_SRT_Status_VH
  as select from zsrt_status
{
      @ObjectModel.text.element: ['StatusText']
      @EndUserText.label: 'Status'
  key status      as Status,

      @Semantics.text: true
      @EndUserText.label: 'Status Text'
      description as StatusText,

      @EndUserText.label: 'Criticality'
      criticality as Criticality
}
