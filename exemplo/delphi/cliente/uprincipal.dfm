object fprincipal: Tfprincipal
  Left = 0
  Top = 0
  Caption = 'RESTDW2RAL - cliente da demo'
  ClientHeight = 461
  ClientWidth = 714
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  PixelsPerInch = 96
  TextHeight = 13
  object mLog: TMemo
    Left = 8
    Top = 48
    Width = 698
    Height = 209
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object grade: TDBGrid
    Left = 8
    Top = 264
    Width = 698
    Height = 189
    DataSource = ds
    TabOrder = 1
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object btPing: TButton
    Left = 8
    Top = 12
    Width = 92
    Height = 29
    Caption = '1. ping'
    TabOrder = 2
    OnClick = btPingClick
  end
  object btSoma: TButton
    Left = 106
    Top = 12
    Width = 92
    Height = 29
    Caption = '2. soma'
    TabOrder = 3
    OnClick = btSomaClick
  end
  object btCadastro: TButton
    Left = 204
    Top = 12
    Width = 92
    Height = 29
    Caption = '3. cadastro'
    TabOrder = 4
    OnClick = btCadastroClick
  end
  object btClientes: TButton
    Left = 302
    Top = 12
    Width = 92
    Height = 29
    Caption = '4. dataset'
    TabOrder = 5
    OnClick = btClientesClick
  end
  object btSigilo: TButton
    Left = 400
    Top = 12
    Width = 92
    Height = 29
    Caption = '5. sigilo'
    TabOrder = 6
    OnClick = btSigiloClick
  end
  object btLista: TButton
    Left = 498
    Top = 12
    Width = 92
    Height = 29
    Caption = 'listar'
    TabOrder = 7
    OnClick = btListaClick
  end
  object cliente: TRALClient
    BaseURL.Strings = (
      'localhost:8000')
    EngineType = 'netHTTP'
    Left = 620
    Top = 8
  end
  object ce: TRALRESTDWClientEvents
    Events = <>
    ModuleRoute = '/'
    RALClient = cliente
    Left = 660
    Top = 8
  end
  object memoria: TFDMemTable
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired, uvAutoCommitUpdates]
    UpdateOptions.CheckRequired = False
    UpdateOptions.AutoCommitUpdates = True
    Left = 580
    Top = 8
  end
  object ds: TDataSource
    DataSet = memoria
    Left = 540
    Top = 8
  end
end
