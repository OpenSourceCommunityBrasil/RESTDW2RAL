object dm_eventos: Tdm_eventos
  Height = 320
  Width = 420
  object srv: TRALRESTDWServerEvents
    Events = <
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'ping'
        Params = <>
        OnReplyEvent = srvEventspingReplyEvent
      end
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'soma'
        Description.Strings = (
          'Soma dois inteiros e devolve o total em um param de saida')
        Params = <
          item
            TypeObject = toParam
            ObjectDirection = odIN
            ObjectValue = ovInteger
            ParamName = 'a'
            Encoded = False
          end
          item
            TypeObject = toParam
            ObjectDirection = odIN
            ObjectValue = ovInteger
            ParamName = 'b'
            Encoded = False
          end
          item
            TypeObject = toParam
            ObjectDirection = odOUT
            ObjectValue = ovInteger
            ParamName = 'total'
            Encoded = False
          end>
        OnReplyEvent = srvEventssomaReplyEvent
      end
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'cadastro'
        Description.Strings = (
          'Mostra odINOUT e o trafego tipado de float e data')
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
            ParamName = 'saldo'
            Encoded = False
          end
          item
            TypeObject = toParam
            ObjectDirection = odINOUT
            ObjectValue = ovDate
            ParamName = 'nascimento'
            Encoded = False
          end>
        OnReplyEvent = srvEventscadastroReplyEvent
      end
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'clientes'
        Description.Strings = (
          'Devolve um dataset inteiro em um parametro')
        Params = <
          item
            TypeObject = toDataset
            ObjectDirection = odOUT
            ObjectValue = ovDataSet
            ParamName = 'dados'
            Encoded = False
          end>
        OnReplyEvent = srvEventsclientesReplyEvent
      end
      item
        BaseURL = '/'
        DefaultContentType = 'application/json'
        EventName = 'sigilo'
        Description.Strings = (
          'Autorizacao por evento, com OnAuthRequest')
        Params = <
          item
            TypeObject = toParam
            ObjectDirection = odIN
            ObjectValue = ovString
            ParamName = 'token'
            Encoded = False
          end>
        OnReplyEvent = srvEventssigiloReplyEvent
        OnAuthRequest = srvEventssigiloAuthRequest
      end>
    OnCreate = srvCreate
    Left = 56
    Top = 40
  end
end
