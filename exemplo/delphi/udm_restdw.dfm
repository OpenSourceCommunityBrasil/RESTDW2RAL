object dm_restdw: Tdm_restdw
  OldCreateOrder = False
  Height = 435
  Width = 574
  object server_events: TRALRESTDWServerEvents
    Events = <
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'ping'
        Params = <
          item
            TypeObject = toParam
            ObjectDirection = odINOUT
            ObjectValue = ovString
            ParamName = 'nome'
            Encoded = False
          end
          item
            TypeObject = toParam
            ObjectDirection = odINOUT
            ObjectValue = ovFloat
            ParamName = 'valor'
            Encoded = False
          end>
        OnReplyEvent = server_eventsEvents0ReplyEvent
      end
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'event1'
        Params = <
          item
            TypeObject = toParam
            ObjectDirection = odINOUT
            ObjectValue = ovString
            Encoded = False
          end>
      end>
    Left = 200
    Top = 264
  end
  object RESTDWServerEvents1: TRESTDWServerEvents
    IgnoreInvalidParams = False
    Events = <
      item
        Routes = [crAll]
        NeedAuthorization = True
        Params = <>
        DataMode = dmDataware
        Name = 'dwevent1'
        EventName = 'dwevent1'
        BaseURL = '/'
        DefaultContentType = 'application/json'
        CallbackEvent = False
        OnlyPreDefinedParams = False
        OnReplyEvent = RESTDWServerEvents1Eventsdwevent1ReplyEvent
      end>
    Left = 328
    Top = 264
  end
end
