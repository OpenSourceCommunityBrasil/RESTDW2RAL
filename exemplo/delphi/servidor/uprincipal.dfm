object fprincipal: Tfprincipal
  Left = 0
  Top = 0
  Caption = 'RESTDW2RAL - servidor da demo'
  ClientHeight = 361
  ClientWidth = 634
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object mLog: TMemo
    Left = 8
    Top = 8
    Width = 618
    Height = 305
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
  object btLigar: TButton
    Left = 8
    Top = 324
    Width = 105
    Height = 27
    Caption = 'Parar'
    TabOrder = 1
    OnClick = btLigarClick
  end
  object server: TRALIndyServer
    Port = 8000
    Left = 528
    Top = 320
  end
  object rdw: TRALRESTDWModule
    Server = server
    Domain = '/'
    ClassModule = 'Tdm_eventos'
    Left = 576
    Top = 320
  end
  object dbm: TRALDBModule
    Server = server
    Domain = '/db'
    DatabaseLink = 'FireDAC'
    DatabaseType = dtSQLite
    Port = 0
    Left = 480
    Top = 320
  end
end
