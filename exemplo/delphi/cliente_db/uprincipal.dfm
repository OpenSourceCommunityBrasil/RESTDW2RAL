object fprincipal: Tfprincipal
  Left = 0
  Top = 0
  Caption = 'RESTDW2RAL - cliente DBWare da demo'
  ClientHeight = 561
  ClientWidth = 794
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  PixelsPerInch = 96
  TextHeight = 13
  object lbClientes: TLabel
    Left = 8
    Top = 52
    Width = 96
    Height = 13
    Caption = 'clientes (master)'
  end
  object lbPedidos: TLabel
    Left = 8
    Top = 224
    Width = 148
    Height = 13
    Caption = 'pedidos (detail, por MasterFields)'
  end
  object btAbrir: TButton
    Left = 8
    Top = 12
    Width = 92
    Height = 29
    Caption = '1. Abrir'
    TabOrder = 0
    OnClick = btAbrirClick
  end
  object btExecSQL: TButton
    Left = 106
    Top = 12
    Width = 92
    Height = 29
    Caption = '2. ExecSQL'
    TabOrder = 1
    OnClick = btExecSQLClick
  end
  object btGravar: TButton
    Left = 204
    Top = 12
    Width = 92
    Height = 29
    Caption = '3. Gravar'
    TabOrder = 2
    OnClick = btGravarClick
  end
  object btApagar: TButton
    Left = 302
    Top = 12
    Width = 92
    Height = 29
    Caption = '4. Apagar'
    TabOrder = 3
    OnClick = btApagarClick
  end
  object btTabelas: TButton
    Left = 400
    Top = 12
    Width = 92
    Height = 29
    Caption = '5. Tabelas'
    TabOrder = 4
    OnClick = btTabelasClick
  end
  object chkAutoCommit: TCheckBox
    Left = 506
    Top = 18
    Width = 142
    Height = 17
    Caption = 'AutoCommitData'
    TabOrder = 5
    OnClick = chkAutoCommitClick
  end
  object gradeClientes: TDBGrid
    Left = 8
    Top = 71
    Width = 778
    Height = 147
    DataSource = dsClientes
    TabOrder = 6
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object gradePedidos: TDBGrid
    Left = 8
    Top = 243
    Width = 778
    Height = 133
    DataSource = dsPedidos
    TabOrder = 7
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'Tahoma'
    TitleFont.Style = []
  end
  object mLog: TMemo
    Left = 8
    Top = 384
    Width = 778
    Height = 169
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 8
  end
  object cliente: TRALClient
    BaseURL.Strings = (
      'localhost:8000')
    EngineType = 'netHTTP'
    Left = 696
    Top = 8
  end
  object conexao: TRALDBConnection
    Client = cliente
    ModuleRoute = '/db'
    Left = 736
    Top = 8
  end
  object qryClientes: TRALRESTDWClientSQL
    DataBase = conexao
    UpdateTableName = 'clientes'
    OnGetDataError = qryClientesGetDataError
    Left = 656
    Top = 96
  end
  object qryPedidos: TRALRESTDWClientSQL
    DataBase = conexao
    UpdateTableName = 'pedidos'
    MasterDataSet = qryClientes
    MasterFields = 'id'
    Left = 696
    Top = 264
  end
  object dsClientes: TDataSource
    DataSet = qryClientes
    Left = 720
    Top = 96
  end
  object dsPedidos: TDataSource
    DataSet = qryPedidos
    Left = 744
    Top = 264
  end
end
