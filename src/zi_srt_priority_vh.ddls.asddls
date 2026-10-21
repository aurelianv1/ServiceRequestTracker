@EndUserText.label: 'Service Request Priority - Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZI_SRT_Priority_VH
  as select from zsrt_priority
{
      @ObjectModel.text.element: ['PriorityText']
      @EndUserText.label: 'Priority'
  key priority    as Priority,

      @Semantics.text: true
      @EndUserText.label: 'Priority Text'
      description as PriorityText,

      @EndUserText.label: 'Max. Days Until Due'
      max_days    as MaxDays,

      @EndUserText.label: 'Criticality'
      criticality as Criticality
}
